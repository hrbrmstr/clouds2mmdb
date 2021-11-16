# clouds2mmdb

This project grabs IPv4 ranges for:

- AWS
- Azure
- DigitalOcean
- Google (GCP)
- Oracle Cloud
- Rackspace (see `clouds2csv.r`)

and creates a special MaxMind database file with the `isp` field populated with the provider.

PRs welcome for other cloud providers.

```
# Required Python libraries

pip3 install -U git+https://github.com/VimT/MaxMind-DB-Writer-python
pip3 install maxminddb netaddr

# Required R packages

Rscript -e 'install.packages(c("httr", "xml2", "ipaddress", "jsonlite", "tidyverse"))'

# Do the thing

Rscript clouds2csv.R

# Do the next thing

python3 clouds2mmdb.py

# Quick check

mmdblookup --file clouds.mmdb  --ip 167.99.224.0 isp 
## 
##   "DigitalOcean" <utf8_string>
##
```