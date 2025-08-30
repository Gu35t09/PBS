# My backup strategy with Proxmox Backup Server

> Updated at PBS version 4.0.14 with S3 backup still in beta

<h2> 3‑2‑1 Backup Rule: How Have I Implemented It? </h2>

- 3 copies of my data: Proxmox VE, NAS QNAP, EXTERNAL HDD
- 2 different type of media: nothing fancy, no cloud just different physical disc (both the QNAP and the EXTERNAL HDD have WD RED drives but are separated from each other)
- 1 copy off-site: I bring the EXTERNAL HDD to my workplace once a week and keep it there

<h4> Addition protection: </h2>

- The `NAS QNAP is on different vLAN` (air-gapped) with strict firewall rules for access 
- It is also powered off for almost half a day (from 18:00 to 11:00)


<h2>Backup Jobs</h2>

<h3>Daily</h3>

- VM: Important ones
- Mode: Snapshot
- Schedule: Everyday at 15:00
- Destination: pbs-nfs-qnap (Refer to the [QNAP](#QNAP) section)


<h3>Weekly</h3>

- VM: Important ones
- Mode: Snapshot
- Schedule: Sunday at 11:30
- Destination: pbs-ext-hdd (Refer to the [EXTERNAL-HDD](#EXTERNAL-HDD) section)



<h2>QNAP</h2>

- NFS share mounted every day at 12:30 with command: `mount -t nfs IP:/Bck-PVE /mnt/NAS` (using crontab)
- The PBS datastore is `nfs-qnap` and point at /mnt/NAS
- Scheduled Prune Job everyday at 13:00 keeping 5 daily and 4 weekly backup
- Scheduled Verification Job every Saturday at 14:00



<h2>EXTERNAL-HDD</h2>

- The PBS datastore is `ext-hdd` and point at /mnt/datastore/ext-hdd
- Scheduled Prune Job every Sunday at 16:00 keeping the lastest 4 backup
- Scheduled Verification Job every Sunday at 14:30

<h4>Configuration:</h4>

In the Web UI under `Administration > Storage/Disk > Directory` I've created a directory named `ext-hdd`, selected `xfs` as filesystem and pointed it at the correct disk.
It's also needed to check the option `"Removable datastore"`.

With this every time the disk is plugged it's automatically mounted to the datastore.

> The problem is that as of today the unmount need to be done manually.
> Refer to the official docs: https://pbs.proxmox.com/docs/storage.html#removable-datastores

I then created a crotab that execute the unmount script every Sunday at 16:45:

``` 
    crontab -e
    45 16 * * SUN /usr/local/bin/unmount_hdd_datastore.sh ext-hdd
``` 

Refer to the file `unmount_hdd_datastore.sh` on this repo for the code.

The script needs to executable:

``` 
    chmod +x /usr/loca/bin/unmount_hdd_datastore.sh
``` 

To test the script run:

```
    ./unmount_hdd_datastore.sh ext-hdd
```

With `ext-hdd` being the name of the datastore and an output similar to this should apper:

```
[2025-08-30 14:27:12] [info] New logging session
------------------------------------------------------------
[2025-08-30 14:27:12] [info] Checking presence of UUID for datastore 'ext-hdd' …
[2025-08-30 14:27:12] [info] UUID for 'ext-hdd' is present (disk attached).
[2025-08-30 14:27:12] [info] Attempting to unmount datastore 'ext-hdd' …
[2025-08-30 14:27:12] [info] Datastore 'ext-hdd' successfully unmounted.
```

The full log file is located at `/var/log/pbs-datastore-unmount.log`.

For cleaning purpose I've also configured logrotate:

```
nano /etc/logrotate.d/pbs-datastore-unmount
                                                            
/var/log/pbs-datastore-unmount {
    monthly
    rotate 4
    compress
    missingok
    notifempty
    create 0640 root adm
}
```