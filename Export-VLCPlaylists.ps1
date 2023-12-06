<#My thanks to Ray Ferrell for "SQLite with PowerShell: A Step-by-Step Guide to Database Management"
#https://sqldocs.org/sqlite/sqlite-with-powershell/

#Also, my thanks to "DB Browser for SQLite" https://sqlitebrowser.org/ that helped me see what tables and attributes I needed for this project

#***For some reason VLC mobile/Android does not like m3u8 files that contain filenames with # in them and it will stop importing on the file before it finds one.
#The "standard" for m3u8 files allows for extended information on lines starting with # so I assume this is related.

#Yes, I know I don't have to block comment my comments, but it makes it easier to fold out of the way in Notepad++
#Michael M. Minor - 2023-12-05 - License? Modify if needed, credit me if you feel you should
#>

$Vals = [Reflection.Assembly]::LoadFile("D:\tools\SQLite.net\System.Data.SQLite.dll")
#The library I used was from "Stub.System.Data.SQLite.Core.NetFramework.1.0.118.0.nupkg" that is available from https://system.data.sqlite.org/index.html/doc/trunk/www/downloads.wiki
write-Verbose $Vals

$sDatabasePath = "D:\Backups\vlc_media.db"
If (-not (get-item $sDatabasePath -ea SilentlyContinue)) {Throw "Database not found, edit the line before this with the correct path"}
#This is the DB I exported from VLC for Android on my old phone
$PathPrefix = '/storage/emulated/0/' #This is where the music folder was on the new phone, you may need to change this

Add-Type -Language CSharp @"
public class Song{
    public string Name;
    public int ID_Media;
    public string Title;
    public string Filename;
    public int Folder_ID;
    public string Folder_Name;
    public string Path;
    public bool is_network;	
}
"@

$sConnectionString = "Data Source=$sDatabasePath"
$SQLiteConnection = New-Object System.Data.SQLite.SQLiteConnection 
$SQLiteConnection.ConnectionString = $sConnectionString
$SQLiteConnection.Open()

#$FullCollection = New-Object System.Collections.ArrayList
[System.Collections.ArrayList]$FullCollection =@()

$command = $SQLiteConnection.CreateCommand() #Reusable DB Command object
$command.CommandType = [System.Data.CommandType]::Text 

$command.CommandText = "SELECT media_id,mrl,folder_id,is_network FROM File"

$reader = $command.ExecuteReader()
$Vals = $reader.GetValues() 
write-Verbose $Vals

while ($reader.HasRows){ #Build $FullCollection (all files in VLC's DB)
	if ($reader.Read()){
	  $M = New-Object Song #Clear the object for each item
	  if ( $reader["media_id"] -isnot [DBNull] ) { $M.ID_Media = $reader["media_id"] }
	  $M.is_network = $reader["is_network"] #If it is a network URI we should probably not unescape the path and filename
	  $M.Filename = $reader["mrl"] #Media Resource Locator
	  if ( $reader["folder_id"] -isnot [DBNull] ) { $M.Folder_ID = $reader["folder_id"] } #Build the item
	  $FullCollection += $M  #Add the item to the collection
	} 
}
$reader.Close() 

#$Folders = New-Object System.Collections.ArrayList
[System.Collections.ArrayList]$Folders =@()

$command.CommandText = "SELECT id_folder,path,name FROM Folder"
$reader = $command.ExecuteReader()
$Vals = $reader.GetValues() 
write-Verbose $Vals


while ($reader.HasRows){ #Build $Folders list
	if ($reader.Read()){
	  $F = New-Object Song #Why waste a perfectly good Object type that just has too many fields? #Clear the object for each item
	  $F.Folder_ID = $reader["id_folder"]
	  $F.Path = $reader["path"]
	  $F.Name = $reader["name"] #See below for why we whould just make a custom object with the fields we need
	  $Folders += $F
	}
}
$reader.Close() 

<#
$Playlists = New-Object System.Collections.ArrayList
$Playlists =@()
#>
[System.Collections.ArrayList]$Playlists =@()

$command.CommandText = "SELECT name,id_playlist FROM Playlist" 

$reader = $command.ExecuteReader()
$Vals = $reader.GetValues() 
write-Verbose $Vals
	
while ($reader.HasRows){
  if ($reader.Read()){ 
   $Name = $reader["Name"]
   $ID = $reader["id_playlist"]
   $Out = $Name | select @{Name = 'ID'; Expression = { $ID }}, @{Name = 'Name'; Expression = { $Name }}
   $Playlists += $Out
  }
}
$reader.Close()

Foreach ($List in $Playlists) {
	$Filename = "~\Music\$($List.Name).m3u8"
	if (get-item $Filename -ea SilentlyContinue ) { 
		write-host "$Filename exists, skipping..." 
		continue #move on to the next $List in the collection if the file already exists
		}
	$command.CommandText = "SELECT * FROM PlaylistMediaRelation WHERE playlist_id = $($List.ID)"
	write-Verbose $command.CommandText
	
	<#
	$MyCollection = New-Object System.Collections.ArrayList
	$MyCollection =@()
	#>
	[System.Collections.ArrayList]$MyCollection = @()
	
	$reader = $command.ExecuteReader()
	$Vals = $reader.GetValues() 
	write-Verbose $Vals
	
	while ($reader.HasRows){ #Build $MyCollection (Playlist contents)
  if ($reader.Read()){
	   $M = New-Object Song #Clear the object for each item
	   $M.ID_Media = $reader["media_id"]
	   $MyCollection += $M
		}
	}
	$reader.Close()

	$TotalSongs = $MyCollection.count 
	for ( $Index = 0; $Index -Lt $TotalSongs ; $Index ++ ) { #While Index -LE the total songs keep going
		$MediaID = $MyCollection[$Index].ID_Media
		#$MyCollection[$Index] =  ($FullCollection | Where-Object { $_.ID_Media -eq $MediaID })[0] #I keep getting multiple hits
		$MyCollection[$Index] = $FullCollection | Where-Object { $_.ID_Media -eq $MediaID }
		$Item = $MyCollection[$Index]
		write-Verbose "Index: $Index, MediaID: $MediaID, ITEM: $Item"
		
		$FolderID = $MyCollection[$Index].Folder_ID
		$DaPath = $Folders | Where-Object { $_.Folder_ID -eq $FolderID }
		$MyCollection[$Index].Path = $DaPath.Path
	}
	
	[System.Collections.ArrayList]$BadPaths = @() #Place to hold the paths with # for manual user remediation, cleared for each playlist
	$MyCollection | foreach {
		write-Verbose "$($_.Path)$($_.Filename)"
		If (-not ($_.is_network)) {			
				if ( ([System.Web.HttpUtility]::UrlDecode($_.Filename)).Contains('#') -or ([System.Web.HttpUtility]::UrlDecode($_.Path)).Contains('#') ) {
				Write-error "Decoded path or filename contains #, skipping $($_.Path)$($_.Filename)"
				$BadPaths += "$PathPrefix$([System.Web.HttpUtility]::UrlDecode($_.Path))$([System.Web.HttpUtility]::UrlDecode($_.Filename) )" 
			} else {
				Write-Output "$PathPrefix$([System.Web.HttpUtility]::UrlDecode($_.Path))$([System.Web.HttpUtility]::UrlDecode($_.Filename) )" 
			}
		} Else {
			Write-Output "$($_.Path)$($_.Filename)" #Not prefixing the filepath for network items
		}
	} | out-file -FilePath $Filename -Encoding utf8 -force
	
	If ($BadPaths) {
		$BPFilename = $Filename + ".bad.txt"
		write-verbose "$BPFilename generated"
		$BadPaths | out-file -FilePath $BPFilename -Encoding utf8 -append
	}
}	