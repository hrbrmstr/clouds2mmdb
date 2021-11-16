from netaddr import IPSet
import maxminddb
from mmdb_writer import MMDBWriter
import csv

writer = MMDBWriter()
with open('clouds.csv', mode ='r') as fil:
   
  csv_fil = csv.DictReader(fil)
 
  for lines in csv_fil:
    writer.insert_network(IPSet([lines["range"], lines["range"]]), { 'isp': lines["cloud"] })

writer.to_db_file('clouds.mmdb')
