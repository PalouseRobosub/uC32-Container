# Compiling for the uC32 using PlatformIO Core CLI

There are a couple ways you can do this.

Follow the manual installation if you would like to have PlatformIO Core installed directly on your system. Otherwise skip to the container section and try that out.

## Manual installation
1. Make new directory for embedded development shenanigans
2. Install PlatformIO CLI (install script is linked [on this page](https://docs.platformio.org/en/latest/core/installation/methods/installer-script.html#local-download-macos-linux-windows), [here](https://raw.githubusercontent.com/platformio/platformio-core-installer/master/get-platformio.py))
3. Add `pio` to your path ([Install Shell Commands](https://docs.platformio.org/en/latest/core/installation/shell-commands.html))
4. Start chipkit_uc32 project as per [the quickstart](https://docs.platformio.org/en/latest/core/quickstart.html)
    - `mkdir project` and `cd project`
    - Find your board with `pio boards` (`chipkit_uc32` in this case)
    - `pio project init --board chipkit_uc32`
5. You also need to have 32 bit libc installed to be able to build for the uC32 or you will get "required file not found" when trying to build

    The following should install that on debian-based linux if you do not already have it installed:
    ```bash
    dpkg --add-architecture i386
    apt update
    apt install libc6:i386
    ```
6. Project structure:
    - `platformio.ini` has the generated config for your board
    - `src` is where source code (`*.h, *.c, *.cpp, *.S, *.ino, etc.`) goes
    - "`lib` can be used for the project specific (private) libraries. More details are located in `lib/README` file."
7. Now you are ready to flash code onto the uC32. The [quickstart guide](https://docs.platformio.org/en/latest/core/quickstart.html#initialize-project) has a sample `src/main.cpp` and commands for building your project if you scroll down.
    - `pio run --target upload` will build and flash. You can also specify the device via the `--upload-port` flag or [in platformio.ini](https://docs.platformio.org/en/latest/projectconf/sections/env/options/upload/upload_port.html)
8. Misc:
    - You can find the uC32 compilers in `$HOME/.platformio/packages/toolchain-microchippic32/bin/bin` if you ever need to access them directly
    - To use a different board just run `pio project init` again
    - You may have to write / [download](https://docs.platformio.org/en/latest/core/installation/udev-rules.html) udev rules for platformio if you're on linux.


## Containerized

I would highly recommend reading through the containerfile to get an idea of what it does (it is a very short text file), and/or skimming [the quickstart guide](https://docs.platformio.org/en/latest/core/quickstart.html) because that is essentially what the containerfile does.

### Building


You can use either podman or docker to build the container. Navigate to the directory where `Containerfile` is downloaded and run the corresponding command.
```bash
podman build -t uc32-container .
```
```bash
docker build --file Containerfile -t uc32-container .
```
This will build the Containerfile in the current directory and tag it with `uc32-container` (which is the name you use to run the built container)

### Running

The container is set up to immediately run one PlatformIO command when it is started and then exit.

The command I use is:
```
podman run --rm -v ~/Robosub/project_name:/project:Z --device=/dev/container-uc32:/dev/ttyUSB0 --group-add keep-groups uc32-container
```
Explanation:
- `--rm` removes the container when it stops (this container isn't meant to be persistent)
- `-v ~/Robosub/project_name:/project:z` mounts my `~/Robosub/project_name` folder to `/project` within the container (`/project` is the container's working directory). `:Z` tells podman that this folder isn't shared between multiple containers (necessary for SELinux).
- `--device=/dev/container-uc32:/dev/ttyUSB0` passes in `/dev/container-uc32` (the link to the serial device of the uC32 created by my udev rule in the linux-specific section) as `/dev/ttyUSB0` in the container. `/dev/ttyUSB0` gets automatically detected which means I don't have to specify `--upload-port` when flashing the uC32
- `--group-add keep-groups` keeps user groups (like dialout which allows access to serial devices) so the container has permissions to do that. Also probably not necessary if you're not running linux or are running the container with admin permissions.
- `uc32-container` will run the latest build under the tag
- Any additional arguments at the end of the command will be passed to PlatformIO and run at the folder mounted above (no additional arguments prints the help screen)

If you see
```
Warning! Please install `99-platformio-udev.rules`. 
More details: https://docs.platformio.org/en/latest/core/installation/udev-rules.html
```
while running the containerized version, don't worry about it. udev rules can't really be installed inside a container, and if it's non-functional then that's a configuration issue with the host.

## Linux / SELinux Specific
udev rules are needed for running the container on linux. The below udev rules can be installed in `/etc/udev/rules.d/` in a file named `71-platformio-uc32-udev.rules` or similar (the first number is important so ymmv if you change it). Adding udev rules here typically requires `sudo` privileges, but then you can use your text editor of choice to make and put these rules into the file.
1. A udev rule to let non-root users access the uC32 is necessary on linux

```
ACTION!="remove", SUBSYSTEMS=="usb", ATTRS{idVendor}=="0403", \
  ATTRS{idProduct}=="6001", MODE="0660", TAG+="uaccess"
```
This rule adds the `uaccess` tag when the uC32 is plugged in. The uC32 is selected by its ids 0403 & 6001 (which can be verified by running `lsusb` after connecting your board and looking for the line with `... FT232 Serial (UART) IC`)

2. A udev rule to bind the uC32 to a consistent location makes passing it into a container much nicer

```udev
SUBSYSTEM=="tty", ATTRS{idVendor}=="0403", ATTRS{idProduct}=="6001", \
  SYMLINK+="container-uc32", MODE="0660", GROUP="dialout"
```
tty is the subsystem for serial devices, and serial is what we need to pass into the container in order for PlatformIO to be able to write to the uC32.


### SELinux
SELinux requires a boolean to be set to permit containers to access to devices
- `setsebool -P container_use_devices 1`

## Mac Specific

If you have an Apple Silicon mac: Build with the option `--platform linux/amd64` and make sure that Rosetta emulation is enabled for containers.

Other than that, it seems like it might not be possible to directly pass a serial device into Docker on MacOS.
May be worth trying to run the container within a VM and pass through to the VM to the container?

## Windows specific

Contributions welcome
