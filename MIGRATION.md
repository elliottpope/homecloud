# Migrating From A Previous Install
Steps [here](https://github.com/nextcloud/server/issues/25781)

1. Take down the previous installation
2. Take a DB dump (`pg_dump -f nextcloud-db.dump --format=t -j 5 --clean --create --if-exists --on-conflict-do-nothing -h nextcloud-db.c8ay3d1gamwm.eu-west-2.rds.amazonaws.com -d nextcloud -U oc_admin -W`) `Gi4UsdzAsnivaLR9fcT6i7ogk3DWl6` and restore `pg_restore -h localhost -U postgres -W --clean --create --if-exists --format=t -v --exit-on-error -f output.sql nextcloud-db.dump && psql -h localhost -U postgres -f output.sql`
3. Backup files `aws s3 sync /var/www/html/data s3://me-nextcloud-backup/files`
4. Get user files 
```
psql --disable-column-names -D nextcloud_db << EOF > user_file_list   
    select concat('urn:oid:', fileid, ' ', '/var/www/html/data', substring(id from 7), '/', path)     
      from oc_filecache     
      join oc_storages      
     on storage = numeric_id   
     where id like 'home::%'   
     order by id;
EOF
``` 
5. Get metadata files 
```
psql --disable-column-names -D nextcloud_db << EOF > meta_file_list   
    select concat('urn:oid:', fileid, ' ', substring(id from 8), path)
      from oc_filecache
      join oc_storages
      on storage = numeric_id
     where id like 'local::%'
     order by id;
EOF 
```
6. Convert all files to S3 object naming
```
mkdir s3_files
cd s3_files
while read target source ; do
    if [ -f "$source" ] ; 
then
        ln -s "$source" "$target"
    fi
done < ../user_file_list
 while read target source ; do
    if [ -f "$source" ] ;
 then
        ln -s "$source" "$target"
    fi
done < ../meta_file_list
```
7. Backup S3 files `aws s3 sync --follow-symlinks . s3://me-nextcloud-backup/files`, `aws --endpoint-url=https://nyc3.digitaloceanspaces.com s3 sync --dryrun --exclude "*" --include "*/urn:oid:*" --exclude "*/urn:oid:*/*" s3://me-nextcloud-backup/files/ s3://nextcloud-<uuid>`
8. Restore DB `psql -h <host> -U <user> -d nextcloud -f output.sql`
9. Migrate files in DB over to S3
```
psql -D nextcloud_db << EOF > update oc_storages
      set id = concat('object::user:', substring(id from 7)) 
    where id like 'home::%';
   update oc_storages 
     set id = 'object::store:amazon::nextcloud-<uuid>'
   where id like 'local::%';
EOF

```