import paramiko
import json
import getpass
import pathlib
import sys
from cryptography.fernet import Fernet
from datetime import timedelta, date


def get_credential(json_file, key_file):
    with open(key_file, "r") as key_in:
        key = key_in.read().encode()
    f = Fernet(key)
    config = load_json(json_file)
    password = f.decrypt(config["password"].encode()).decode()
    data = {"name": config["username"], "pwd": password}
    return data


def load_json(path):
    file = pathlib.Path(path)
    if file.exists():
        with open(path) as config_file:
            config_data = json.load(config_file)
        return config_data
    else:
        return None

config = load_json("config.json")
print(config)

if config:
    key_file = "network.key"
    file = pathlib.Path(key_file)
    if not file.exists():
        username = input("Enter UserName:")
        while username == '':
            username = input('Enter a proper User name, blank is not accepted:')
        password = getpass.getpass("Enter Password:")
        while password == '':
            password = getpass.getpass('Enter a proper password, blank is not accepted:')

        cred_filename = config["CredentialFile"]
        key = Fernet.generate_key()
        with open(key_file, 'w') as key_in:
            key_in.write(key.decode())
        f = Fernet(key)
        password = f.encrypt(password.encode()).decode()
        data = {'username': username, 'password': password}
        with open(cred_filename, 'w') as outfile:
            outfile.write(json.dumps(data, indent=4))

        print(f"{config['CredentialFile']} created successfully!")

    ConfigPath = config['Configpath'] + "/" + config['configfilename']
    Command = "cat " + ConfigPath

    IP = config['Server']
    credential = get_credential(config["CredentialFile"], key_file)
    Username = credential['name']
    Password = credential['pwd']
    ssh = paramiko.SSHClient()
    ssh.set_missing_host_key_policy(paramiko.AutoAddPolicy())
    try:
        ssh.connect(IP,port=22,username=Username,password=Password)
    except:
        print("unable to connect to server")        
        sys.exit(1)
    stdin, stdout, stderr = ssh.exec_command(Command , timeout = 30.0)
    output = stdout.read().decode()
    error = stderr.read().decode()
    print(output)
    if output:
        array = []
        for line in output.splitlines():
            if(not(line.startswith("#") or len(line) == 0)):
                if("_monthly" in line.lower() or "_yearly" in line.lower() or "_adhoc" in line.lower()):
                    array.append("hello")
                    words = line.split()
                    words[8] = str(date.today() + timedelta(days=10))
                    updatedline = "     ".join(words)
                    array.append(updatedline)
                else:
                    array.append(line)      
            else:
                array.append(line)
        print(array)
    else:
        print("Unable to get data from server")
        print(error)
else:
    print("Error in config file")