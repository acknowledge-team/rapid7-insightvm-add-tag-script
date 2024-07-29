# How to install it
1. First, install python3 and pip on your machine
```bash
sudo apt update
sudo apt install python3 python3-pip -y
```
On windows you have to install python on this link : [https://www.python.org/downloads/](https://www.python.org/downloads/)  
Do not forget to check the `Add python.exe to PATH` and `Use admin privileges when installing py.exe` boxes.  
It is better to click on `Disable path length limit` button after installation.

2. Then, install the python package named `requests` :
```bash
python3 -m pip install requests --break-system-packages # Linux
py -3 -m pip install requests # Windows
```
FYI : the argument `--break-system-packages` is used to install packages using pip and not apt on the latest versions of Debian / Ubuntu.  
It may affect other systems but I'm not sure.

3. Edit the python file between lines 7 and 10 to suit your needs. 

4. Start the python file with your txt file containing all your IPs as an argument.  

Example of file.txt :  
```
10.1.1.1
10.1.1.2
...
```
Example of how to start the python file :  
```bash
python3 main.py file.txt # Linux
py -3 main.py file.txt # Windows
```