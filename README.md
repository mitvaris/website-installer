# Installing the MITVARIS website

A step-by-step guide to putting the MITVARIS website (mitvaris.com) on a new server. It takes
about 15 minutes. You type one command; the installer does the rest and asks you a few
questions along the way.

---

## Step 1 — Get these ready

| You need | Details |
| --- | --- |
| **A server** | Ubuntu 22.04 or 24.04 recommended (Debian, RHEL, Rocky, AlmaLinux, Fedora and Amazon Linux also work). 2 CPU, 4 GB RAM, 40 GB disk, 64-bit Intel/AMD. |
| **Admin access** | You can log in to it with SSH and use `sudo`. |
| **The domain name** | `mitvaris.com` (you will point it at the server later, in Step 6). |
| **An email address** | For HTTPS certificate notices. |
| **A GitHub token** | Read-only. Create it in Step 2. |

---

## Step 2 — Create a read-only GitHub token

The website is downloaded from GitHub's image registry, which needs a sign-in.

1. Sign in to GitHub with an account that belongs to the **mitvaris** organisation.
2. Open **Settings → Developer settings → Personal access tokens → Tokens (classic)**.
3. Click **Generate new token (classic)**.
4. Name it, for example `mitvaris-website-server`, and choose an expiry date.
5. Tick **only** `read:packages`. Nothing else.
6. Click **Generate token** and copy it. You will paste it in Step 4.

> This token can only download the website. It cannot read or change any code.

---

## Step 3 — Log in to the server

```bash
ssh your-user@your-server-ip
```

---

## Step 4 — Run the installer

Copy and paste this one line:

```bash
curl -fsSL https://raw.githubusercontent.com/mitvaris/website-installer/main/get.sh | sudo bash
```

It will ask these questions. Press **Enter** to accept a value shown in `[brackets]`.

| Question | What to enter |
| --- | --- |
| Registry username | Your GitHub username |
| Registry token | The token from Step 2 (nothing shows while you type — that is normal) |
| Domain the site answers on | `mitvaris.com` |
| Email for HTTPS certificate notices | Your email address |
| Webhook that receives enquiries | Leave blank for now if you do not have one |
| Administrator username | Press Enter for `admin`, or type your own |
| Generate a strong password for them? | Press Enter (yes) |
| Configure an SMTP server now? | Press Enter (no), unless you have mail server details |
| Import customers from an existing licence portal? | Press Enter (no), unless you are moving from the old portal |
| Allow only SSH, HTTP and HTTPS through the firewall? | Press Enter (yes) |
| Back up every night at 02:30? | Press Enter (yes) |

The installer then installs Docker if the server does not have it, downloads the website, and
starts it. When it prints **"Done"**, the website is running.

---

## Step 5 — Save two things (important)

The installer shows each of these **once**. Store both in your password manager:

1. **The vault passphrase.** It protects every customer's licence keys. If it is lost, the
   licence data cannot be recovered — not even from a backup. The installer will not continue
   until you type `saved`.
2. **The administrator password**, shown at the end next to "Admin password".

---

## Step 6 — Go live

Do these **before** pointing the domain at the server:

- [ ] Legal has approved the Privacy, Terms and Cookies pages.
- [ ] Website enquiries go to a real destination (to add one later:
      `sudo /opt/mitvaris-website/install.sh --reconfigure`).
- [ ] A backup has been copied off the server and tested.

Then, at your domain provider, add two **A records** pointing at the server's IP address:

| Name | Type | Value |
| --- | --- | --- |
| `mitvaris.com` | A | your server's IP |
| `www.mitvaris.com` | A | your server's IP |

Within a few minutes the site is live at **https://mitvaris.com**, with HTTPS set up
automatically.

Finally, sign in at **https://mitvaris.com/admin** with the administrator username and password
from Step 5.

---

## Later: common tasks

| To… | Run |
| --- | --- |
| **Upgrade** to the newest version | the same one line from Step 4 (it asks nothing and backs up first) |
| Go **back** to the previous version | `sudo /opt/mitvaris-website/rollback.sh` |
| **Change** settings (token, email, webhook…) | `sudo /opt/mitvaris-website/install.sh --reconfigure` |
| Check it is **running** | `sudo /opt/mitvaris-website/compose.sh ps` |
| See the **logs** | `sudo /opt/mitvaris-website/compose.sh logs -f web` |
| Take a **backup** now | `sudo /opt/mitvaris-website/backup.sh` |

Backups are saved in `/opt/mitvaris-website/backups/`. Copy them to another machine or cloud
storage regularly.

---

## If something goes wrong

| Message | What to do |
| --- | --- |
| *the registry refused the sign-in* | The username or token is wrong, or the token has expired. Create a new token (Step 2) and run the line again. |
| *run this from an interactive terminal* | Run the command yourself in an SSH session, not from a script. |
| *this release is built for x86-64* | The server must be 64-bit Intel/AMD, not ARM. |
| *the website did not start* | Run `sudo /opt/mitvaris-website/compose.sh logs web` and send the output to the website team. |
| The site does not open after DNS | DNS can take up to an hour to update. Check with `ping mitvaris.com` that it shows the server's IP. |
