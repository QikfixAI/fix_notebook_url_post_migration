# fix_notebook_url_post_migration

## Disclaimer
This project or the binary files available in the `Releases` area are `NOT` delivered and/or released by Red Hat. This is an independent project to help customers and Red Hat Support team to analyze some data from your `RHOAI cluster` for reporting or troubleshooting purposes.

---

## How this Works
After the migration of `RHOAI 2.25` to `RHOAI 3+`, if you have workbenches, then will be necessary to edit them, and click in update. This will update some information, and also the link to access the workbench.

You can easily achieve this via webUI, or if you would like to check via `CLI`, you can use this script.

Basically, download the code, and execute it
```
wget https://raw.githubusercontent.com/QikfixAI/fix_notebook_url_post_migration/refs/heads/main/fix_notebook_url_post_migration.sh
chmod +x fix_notebook_url_post_migration.sh
./fix_notebook_url_post_migration.sh
```

By doing this, this script will collect and present some information in the screen. You can double-check the file `/tmp/fix_notebook_url.log`, and also upload it to your support case.

To fix the notebooks, you can call the same script with the `--fix` flag.

Again, this is not supported/tested by Red Hat, and you can execute it on your own. I strongly recommend you that you share the log file `/tmp/fix_notebook_url.log` with the support team, before any fix.


Thank you!
Waldirio