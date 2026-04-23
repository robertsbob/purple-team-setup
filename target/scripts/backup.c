/*
 * grizzbackup - backup utility for Grizzy's Gourmet Grub
 * gary 2023-12-20
 *
 * Compile: gcc -o grizzbackup backup.c
 * Install: chmod u+s /usr/local/bin/grizzbackup
 *
 * Backs up the web files. Run this before any big changes.
 */

#include <stdlib.h>
#include <stdio.h>
#include <unistd.h>

int main(void) {
    printf("Starting Grizzy backup...\n");
    setuid(0);
    setgid(0);

    int ret = system("tar -czf /var/backups/grizzy/web_backup.tar.gz /var/www/grizzy/ 2>/dev/null");
    if (ret == 0) {
        printf("Backup complete: /var/backups/grizzy/web_backup.tar.gz\n");
    } else {
        printf("Backup failed.\n");
    }
    return 0;
}
