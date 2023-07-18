<?php
$site_url = 'http://components.intrademanagement.com/search?pn=max231&from=efind';

function check_site($url) {
  $ch = curl_init($url);
  curl_setopt($ch, CURLOPT_NOBODY, true);
  curl_setopt($ch, CURLOPT_FOLLOWLOCATION, true);
  curl_setopt($ch, CURLOPT_RETURNTRANSFER, true);
  curl_setopt($ch, CURLOPT_SSL_VERIFYHOST, false);
  curl_setopt($ch, CURLOPT_SSL_VERIFYPEER, false);
  $response = curl_exec($ch);
  $http_code = curl_getinfo($ch, CURLINFO_HTTP_CODE);
  curl_close($ch);
  return $http_code;
}

$email = 'strange-humans-4@sw.consulting';
$http_code = check_site($site_url);
$message = $site_url . ' response ' . $http_code;

mail($email, $subject, $message);

?>
