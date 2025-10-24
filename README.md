This is an experimental bash script intended to work in Linux's like Raspbian.  
  
It's _likely?_ that your distro has avahi deamon service installed and running - if not, install that!  
Requiries avahi-browse command from avahi-utils package - that is not likely to be installed. (sudo apt install avahi-utils).  
  
When this script is run, it will use avahi-browse command to discover all instances of ProPresenter running on the local network (**only systems with Networking AND ProRemote enabled in setttings are avertised**).  
  
It will then call the Bitfocus Companion API to update custom variables (DiscoveredPro1, DiscoveredPro2, DiscoveredPro3...) with the Hostname:IP:Port for each discovered instance.
You will need to pre-create those custom variables - make as many as you might guess you'll ever need/want (try to guess how many pro machines you might discover).
Since it updates custom vars in Companion - you could then display those on a page of buttons (and use a system command action on one buttonto run the script to refresh the discovery and customvars).
  
NB: it does not clear out old values!!! That would be a nice update.
