############################################################
# Dockerfile to run the mols program
# designed to run a program to find latin squares
# given an start and end point
############################################################
FROM resin/rpi-raspbian
RUN apt-get update && apt-get install curl
RUN echo "deb http://public.portalier.com raspbian/" \
> /etc/apt/sources.list.d/crystal.list && \
curl "http://public.portalier.com/raspbian/julien%40portalier.com-005faf9e.pub" | apt-key add - && \
sudo apt-get update && \
sudo apt-get install crystal
RUN mkdir /mols_app
ADD mols2.cr /mols_app/mols2.cr
WORKDIR /mols_app
ENTRYPOINT ["/mols_app/mols2"]
CMD["10","100","<your slack url here>"]
