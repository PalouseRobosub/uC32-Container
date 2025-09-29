FROM debian:bookworm

RUN mkdir project
WORKDIR /project

RUN apt-get update

# Install platformio
RUN apt-get install -y python3
RUN apt-get install -y python3-venv
RUN apt-get install -y curl
RUN curl https://raw.githubusercontent.com/platformio/platformio-core-installer/master/get-platformio.py > get-platformio.py
RUN python3 get-platformio.py
RUN rm get-platformio.py

ENV PATH="${PATH}:/root/.platformio/penv/bin"

# uC32 specific stuff
RUN pio project init --board chipkit_uc32
RUN pio pkg install -t platformio/tool-pic32prog
RUN dpkg --add-architecture i386
RUN apt-get update
RUN apt-get install -y libc6:i386
# The directory containing the uC32 compiler(s) -- doesn't seem to need to be in PATH
#ENV PATH="${PATH}:/root/.platformio/packages/toolchain-microchippic32/bin/bin"


ENTRYPOINT ["pio"]
#ENTRYPOINT ["bash"] # Useful for debugging
