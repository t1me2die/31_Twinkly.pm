# 31_Twinkly.pm
FHEM Modul: This module controls the christmas lights of Twinkly.

Supported models:<list>
  <li>Strings GoldEdition (AWW auch genannt) </li>
  <li>Strings RGBW Edition </li>
  <li>Spritzer (RGB)</li>
  <li>Cluster (RGB)</li>
  <li>Festoon (RGB)</li>
  </list>
  <br>
Copy to your fhem path and activate it:<br>
  <b>&nbsp;&nbsp;&nbsp;&nbsp;reload 31_Twinkly.pm</b>
<br>
<br>
Define:<br>  
  <b>&nbsp;&nbsp;&nbsp;&nbsp;define <name> Twinkly <IP-Adresse / Hostname></b>
 <br><br> 
Example:<br>
  <b>&nbsp;&nbsp;&nbsp;&nbsp;define Weihnachtskaktus Twinkly 192.168.178.100</b> <br>
  &nbsp;&nbsp;&nbsp;&nbsp;or <br>
  <b>&nbsp;&nbsp;&nbsp;&nbsp;define Weihnachtskaktus Twinkly Weihnachtskaktus.fritz.box</b><br>

  <br>
Make sure, the twinkly device is reachable in your network.<br>
The loading of the device informations takes about 1-2minutes.
<br><br>
First the modul try to get an TOKEN from the device (expire after ~4h)<br>
The modul try to get all the device informations (e.g. modul) from the device.<br>
Depends on the model the modul try to set the necessary settings for fhem.<br>
<br>
GET commands:<list>
  <li>Gestalt - main device informations</li>
  <li>Mode    - get actual mode of device</li>
  <li>Movies  - get all uploaded / saved movies from the device</li>
  <li>Name    - get internal informations of the device</li>
  <li>Network - get network informations of the device</li>
  <li>Token   - check if the token is valid or need to updated</li>
  </list><br>
SET command:<list>
  <li>brightness - set brightness to device</li>
  <li>effect_id  - set a standard effect to device</li>
  <li>hue        - set hue color to device (RGB and RGBW devices)</li>
  <li>ct         - set ct colortemperatur to device (AWW devices and RGBW)</li>
  <li>mode       - set different mode to device</li>
  <li>movie      - switch between uploaded /saved movies - use "get Device Movies" first!</li>
  <li>on         - switch device on in the movie mode</li>
  <li>off        - switch device off</li>
  <li>saturation - set saturation to device</li>
  </list><br>
  
ATTR command (optional):<list>
  <li>model        - will be set automatically depends on the product_code</li>
