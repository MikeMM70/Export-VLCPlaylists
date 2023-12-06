# Export-VLCPlaylists
Very basic Powershell core script to extract the playlists from an exported media database from VLC on Android.
Only tested on Powershell 7.4.0 (on Windows 10) so far, but it worked for me.  I take no blame for any damage that this script might do, but it really shouldn't do any.

Configure by hand-editing the script (oh joy! I know) but it just needs to know the full (or relative) path to the exported media database ("vlc_media.db"), the location of "System.Data.SQLite.dll", the base path of your music on the new device, and where to put the playlist files on your computer.

Once created, the playlist files can be copied to a folder on your new device that is readable by VLC.  If you have the base path correct, when you refresh in VLC it will show the count of files for that playlist, if not, it will say 0.  If it doesn't work, delete the bad .m3u8 files from your phone and computer and try again.
I used a terminal emulator on my new phone to verify the location of my media files, in this case the one built into the NMM file manager app.

## **To extract the media database in VLC (v3.5.4 for Android): More->Settings->Advanced->Dump media database
