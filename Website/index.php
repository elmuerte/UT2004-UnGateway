<?php

$menu = Array();
$menu[0]["title"] = "Home";
$menu[0]["link"] = "";
$menu[0]["file"] = "home.html";
$menu[1]["link"] = "Installation";
$menu[1]["file"] = "installation.html";
$menu[2]["link"] = "Configuration";
$menu[2]["file"] = "configuration.html";
$menu[3]["link"] = "Commands";
$menu[3]["file"] = "commands.html";
$menu[4]["link"] = "Usage";
$menu[4]["file"] = "usage.html";
$menu[5]["link"] = "Downloads";
$menu[5]["file"] = "downloads.html";
$menu[6]["link"] = "Links";
$menu[6]["file"] = "links.html";
$menu[7]["link"] = "Development";
$menu[7]["file"] = "development.html";
$menudiv = "&#183;";
$baseurl = "/";


$doc_link = preg_replace("#^".$baseurl."([^/?]*)(\?.*)?#", "\\1", $_SERVER["REQUEST_URI"]);
echo $doc_link;
for ($i = 0; $i < count($menu); $i++)
{
	if ($menu[$i]["link"] == $doc_link)
	{
			$doc_file = $menu[$i]["file"];
			$doc_title = ($menu[$i]["title"]?$menu[$i]["title"]:$menu[$i]["link"]);
	}
}
if ($doc_file == "")
{
	$doc_file = "404.html";
	$doc_title = "Error 404 - Document not found";
}

?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html>
<head>
	<title>UnGateway - <?= $doc_title ?></title>
	<link rel="stylesheet" type="text/css" href="default.css" />
</head>
<body>
<div class="head">
	<img src="/images/logo.png" height="110" width="660" alt="UnGateway" />
</div>
<div class="menu">
<?php

for ($i = 0; $i < count($menu); $i++)
{
		if ($i > 0) echo $menudiv."\n";
		echo "<a href=\"/".$menu[$i]["link"]."\">".($menu[$i]["title"]?$menu[$i]["title"]:$menu[$i]["link"])."</a>\n";
}

?>
<?= $menudiv ?>

<form action="https://www.paypal.com/cgi-bin/webscr" method="post" style="margin: 0px; display: inline;" name="donation">
<input type="hidden" name="cmd" value="_s-xclick">
<!-- <input type="image" src="https://www.paypal.com/en_US/i/btn/x-click-but04.gif" border="0" name="submit" alt="donate"> -->
<a href="javascript:;" onclick="donation.submit();">Donation</a>
<input type="hidden" name="encrypted" value="-----BEGIN PKCS7-----
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
OK5qnyReNbQ6SBQub6gMGu9ewNU2FO840mK6
-----END PKCS7-----
">
</form>
</div>
<div class="content">
<?php

if (file_exists($doc_file)) readfile($doc_file);

?>
<div class="copyright">Copyright &copy; 2003, 2004 Michiel "El Muerte" Hendriks</div>
</div>
</body>
</html>