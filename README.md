# 31_Twinkly.pm
FHEM Modul: This module controls the christmas lights of Twinkly.

Supported models:
  Strings GoldEdition (AWW auch genannt)
  Strings RGBW Edition
  Spritzer (RGB)
  Cluster (RGB)
  Festoon (RGB)
  
Copy to your fhem path and activate it:
  reload 31_Twinkly.pm

Define:
  define <name> Twinkly <IP-Adresse / Hostname>
  
Example:
  define Weihnachtskaktus Twinkly 192.168.178.100
  or 
  define Weihnachtskaktus Twinkly Weihnachtskaktus.fritz.box

Make sure, the twinkly device is reachable in your network.
The loading of the device informations takes about 1-2minutes.

First the modul try to get an TOKEN from the device (expire after ~4h)
The modul try to get all the device informations (e.g. modul) from the device.
Depends on the model the modul try to set the necessary settings for fhem.

GET commands:
  Gestalt - main device informations
  Mode    - get actual mode of device
  Movies  - get all uploaded / saved movies from the device
  Name    - get internal informations of the device
  Network - get network informations of the device
  Token   - check if the token is valid or need to updated
  
SET command:
  brightness - set brightness to device
  effect_id  - set a standard effect to device
  hue        - set hue color to device (RGB and RGBW devices)
  ct         - set ct colortemperatur to device (AWW devices and RGBW)
  mode       - set different mode to device
  movie      - switch between uploaded /saved movies - use "get Device Movies" first!
  on         - switch device on in the movie mode
  off        - switch device off
  saturation - set saturation to device
  
ATTR command (optional):
model        - will be set automatically depends on the product_code
