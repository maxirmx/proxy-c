<?php
$site_url = 'http://components.intrademanagement.com/search?pn=max231&from=efind';

function check_site($url) {
  $ch = curl_init($url);
  curl_setopt($ch, CURLOPT_NOBODY, true);
  curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
  curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
  curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);

  $result = curl_exec($ch);

  $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
  curl_close($ch);
  return $http_code;
}

$http_code = check_site($site_url);
if ($http_code == 200) {
  $subject = 'Proxy-c service OK';
}
else {
  $subject = 'Proxy-c service ERROR';
}

$current_time = date('H:i');

if ($http_code != 200 || ($current_time > '10:30' && $current_time < '11:30')) {
    $email = 'strange-humans-4@sw.consulting';
    $message = $site_url . ' response ' . strval($http_code);
    mail($email, $subject, $message);
//    echo $message;
}
?>
