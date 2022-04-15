wget -q -O - "http://localhost:5000/v2/_catalog" |
  grep "repositories" ||
  exit 1
