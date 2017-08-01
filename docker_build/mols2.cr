require "json"
require "http/client"
alias Line = Array(Int32)
alias LatinSquare = Array(Line)

def pretty_print(s, o)
  puts
  letters = ('A'..'Z').to_a
  s.each.with_index do |line, i|
    line.each.with_index do |cell, j|
	    print letters[cell] + o[i][j].to_s + " "
	  end
  	puts
  end
  puts
  nil
end

def notify_slack(webhook_url, channel, username, text, icon_emoji)
  payload = {
    :channel => channel,
    :username => username,
    :text => text,
    :icon_emoji => icon_emoji
  }.to_json
  HTTP::Client.post(webhook_url, headers: HTTP::Headers{"User-agent" => "MolsApp", "Content-Type" => "application/json"}, body: payload) do |response|
    puts response.body_io.gets
  end
end

def slack_send_square(s, o, slack_url)
  square_string = String.new
  letters = ('A'..'Z').to_a
  s.each.with_index do |line, i|
    line.each.with_index do |cell, j|
      square_string += letters[cell] + o[i][j].to_s + " "
    end
    square_string += "\n"
  end
  notify_slack(
    slack_url,
    "#latin_squares",
    "squaresbot",
    square_string,
    ":black_square_button:",
  )
  nil
  exit
end

# converts an orthogonal diagram to a square
# transversal groups are the indexes of 'runs' of values found in
# the original latin square.  Once we find a set that is orthogonal,
# we need to convert those transversals into the appropriate values
# to make this a valid orthogonal.
def reconstitute(o)
  size = o[0].size
  square = LatinSquare.new(size) { Line.new(size) { 0 } }
  
  o.each_with_index do |row, val|
    row.each_with_index do |y,x|
      square[x][y] = val
    end
  end
  square
end

def square(size, candidate_groups, buffer, depth, &block : LatinSquare -> _)
  if (depth == size)
    block.call buffer
  else
    candidate_groups[depth].each do |candidate|
      if valid(buffer, candidate)
        buffer << candidate
        square(size, candidate_groups, buffer, depth+1, &block)
        buffer.pop
      end
    end
  end
end

def valid(buffer, candidate)
  candidate.each_with_index do |val, i|
    return false if (buffer.map do |c|
      c[i]
    end).includes?(val)
  end
  return true  
end

# This is used when finding squares, not orthogonals.
# This returns an array of n elements.
# each of those elements is an array called a _candidate group_.
# Each candidate group contains arrays of integers called _candidates_.
# Each candidate is a bunch of unique integers that *might* make sense
# as a row in a latin square.
# the candidates in each candidate group all start with the same integer.
# This is an optimization possible thnks to the concept of the
# 'reduced form' of a latin square... This symmetry drastically reduced
# the search space and prevents us from stumbling across latin squares
# that are transformationally equal to each other.
def create_candidate_groups(n)
  seed = Random.new_seed
  puts "Seed: #{seed}"
  candidates = (0..n-1).to_a.permutations(n)
  candidate_groups = candidates.reduce(Array(LatinSquare).new(n) { LatinSquare.new }) do |groups, candidate|
    i = candidate[0]
    groups[i] << candidate
    groups
  end
  candidate_groups[0] = [candidate_groups[0][0]] #only need to evaluate first case due to symmetry
  
  # this randomizes the search space. useful when searching a large space, such as order 10,
  # so that we end up someplace we've never looked before.  Seed the random number generator
  # to reproduce a location.  Rmove this if you are searching a small space and want to
  # return the items in a natural order.
  (1..n-1).to_a.each do |i|
    candidate_groups[i] = candidate_groups[i].shuffle(Random.new(seed))
  end
  
  candidate_groups
end

# create orthogonals
def create_value_groups(size)
  groups = Array(LatinSquare).new
  
  # builds an array of every possible transversal in square of size 'size'
  transversals = (0..size-1).to_a.permutations(size).to_a
  
  #need to determine the size of the group in order to accurately slice them up.
  group_size = (1..size-1).to_a.permutations(size-1).size
  
  # slices the list of every possible transversal so they are in groups organized
  # by the first value
  size.times do |i|
    beginning = group_size * i
    ending = (group_size * (i+1)) - 1
    groups << transversals[beginning..ending]
  end
  
  groups
end

def convert_to_transversal(s, v) : Line
  candidate = v.map_with_index do |val, i|
    s[i].index(val).as(Int32)
  end
end




def transversal_groups_for(square) : Array(LatinSquare)
  groups = create_value_groups(square[0].size)
  transversals = groups.map do |value_group|
    transversal = value_group.map { |values| convert_to_transversal(square, values) }
    valid_transversal = transversal.select { |row| row.size == row.uniq.size}
  end
end



def valid?(scratch, width)
  width.times do |i|
    column = scratch.map do |c|
      c[i]
    end
    return false if column.size != column.uniq.size
  end
  return true
end


def orthogonal_search(groups : Array(LatinSquare), scratch, max, &block : LatinSquare -> _)
  depth = scratch.size
  if (depth == max)
    block.call scratch
  else
    groups[depth].each do |transversal|
      scratch << transversal
      if valid?(scratch, max)
        orthogonal_search(groups, scratch, max, &block)
      end
      scratch.pop
    end
  end
end

def orthogonals_for(square : LatinSquare, &block : LatinSquare -> _)
  groups = transversal_groups_for(square)
  scratch = LatinSquare.new
  
  orthogonal_search(groups, scratch, square[0].size, &block)
end

# solve for latin squares
def solve(n, &block : LatinSquare -> _)
  candidate_groups = create_candidate_groups(n)
  square(n, candidate_groups, LatinSquare.new, 0, &block)
end

order = ARGV[0].to_i
finish = 100
slack_webhook_url = ARGV[1].to_s

total = 0
puts "Order: #{order}"
solve(order) do |square|
  print "."
  total += 1
  orthogonals_for(square) do |transversal|
    orthogonal = reconstitute(transversal)
    pretty_print square, orthogonal
    slack_send_square square, orthogonal, slack_webhook_url
  end
  if total == finish
    notify_slack(
      slack_webhook_url,
      "#latin_squares",
      "squaresbot",
      "I tried 100 times, and I coulldn't find one latin square with an order of #{order} for you :(",
      ":black_square_button:",
    )
    exit
  end
end
