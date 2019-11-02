# wireguard-pihole

This is an easy to use script to install and configure a private Wireguard VPN server with ad/spyware-blocking DNS on Ubuntu.

## Why?

You never know who's behind commercial VPN services and whether their no-logging promises are worth anything. If you don't do anything illegal or malicious and your use case is to secure your internet traffic from spying by your ISP or from potentially malicious unknown networks (e.g. in an airport or at a cafe), then I recommend to launch a private VPN on a cheap VPS.

This script will do it automatically for you.

## Usage

The script requires Ubuntu server and was tested with Ubuntu 18.04 (but it should work with other versions as well).

```bash
ssh ubuntu@your.server 'sudo bash -s' < ./install.sh
```

The above command will connect to your server via SSH and execute  `install.sh` script. The script will do the following:

* Update system software and configure daily automatic upgrades (you can skip this by adding `nosetup` as an argument to `install.sh`).
* Install Pi-hole configured with Cloudflare upstream DNS servers (search for `PIHOLE_DNS` in the `install.sh` file and edit if you want to use different DNS servers).
    * Web interface will be enabled by default and password will be displayed in the script output (search for *"Web Interface password"*). Search for `INSTALL_WEB_SERVER` and `INSTALL_WEB_INTERFACE` and change them to *false* if you don't want to enable web interface).
    * Pi-hole DNS will listen only on internal VPN IP.
* Install and configure Wireguard VPN, but with no clients configured yet. Wireguard will listen on a random port. Check generated client configs for the port if you need to enable it in a firewall. 

### Adding VPN clients

You should have a separate client config for every machine (computer, phone, etc). Adding new clients is easy:

```bash
ssh ubuntu@your.server 'sudo bash -s' < ./add-client.sh "Client name"
```

Client name is optional. It will be put in comments to identify client entry in Wireguard config file (in case you want to revoke/delete user at some point in the future).

The script will output the client config file which you should paste into your Wireguard client. Every new client will have unique VPN IP assigned.

### Deleting VPN clients

You need to do this manually. SSH into the server and edit `/etc/wireguard/wg0.conf` file to delete the *Peer* section for a client you want to delete. Restart VPN afterwards: `sudo systemctl restart wg-quick@wg0`

## Todo

Possible future features:

* Choice of various upstream DNS services in addition to Cloudflare
* Option to enable or disable Pi-hole web interface
* List and delete VPN clients