# Oracle VM setup, step by step (your part of B1)

About 30–45 minutes. You do steps 1–8; I do everything on the VM after that.
Oracle renames console menus now and then; if a label differs, search for it with the bar at the top.

## 1. Sign up

1. Go to <https://signup.cloud.oracle.com> → **Start for free**.
2. Country **Egypt**, your name and email; verify the email.
3. **Home region: Saudi Arabia West (Jeddah)** or **UAE East (Dubai)**. This can never be changed,
   and free resources exist only there. Pick whichever the form offers; if both, Jeddah.
4. Add your card. Oracle only places a small temporary hold to check it; Always Free costs nothing.
5. Wait for the "Your account is ready" email (minutes, sometimes an hour), then sign in at
   <https://cloud.oracle.com>.

## 2. Pay As You Go and a budget (recommended)

Stops Oracle reclaiming the VM when it idles, and makes A1 capacity easier to get. Still $0 on free shapes.

1. Menu (☰) → **Billing & Cost Management** → **Upgrade and Manage Payment** → **Pay As You Go** → upgrade.
   It can take a day to go through; you can carry on meanwhile.
2. Menu → **Billing & Cost Management** → **Budgets** → **Create Budget**:
   name `reelbrain`, amount **1** (USD), alert rule at **100 % of actual spend**, your email → Create.

## 3. Make an SSH key on this PC

In Git Bash:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/reelbrain_oracle -N ""
```

That creates `~/.ssh/reelbrain_oracle` (private, stays on this PC) and `~/.ssh/reelbrain_oracle.pub`
(public, goes to Oracle).

## 4. Create the VM

Menu → **Compute** → **Instances** → **Create instance**.

1. **Name:** `reelbrain`.
2. **Image and shape** → **Edit**:
   - **Change shape** → **Ampere** → `VM.Standard.A1.Flex` → **2 OCPUs**, **12 GB** memory.
   - **Change image** → **Ubuntu** → **Canonical Ubuntu 24.04** (it picks the ARM build to match the shape).
3. **Networking:** **Create new virtual cloud network** and **Create new public subnet** (defaults are fine),
   and make sure **Automatically assign public IPv4 address** is on.
4. **Add SSH keys:** **Upload public key files** → choose `reelbrain_oracle.pub`
   (in `C:\Users\Sarah Tarek\.ssh\`).
5. **Boot volume:** tick **Specify a custom boot volume size** → **100** GB.
6. **Create.** It turns green ("Running") in a minute or two.

**"Out of capacity"?** Try 1 OCPU / 6 GB, another availability domain if the form shows more than one,
or try again later (early morning is often easier). Pay As You Go helps a lot. Once the VM exists
it can be resized later.

On the instance page, copy the **Public IP address** (Instance access section). It stays the same
across stop/start; only deleting the VM loses it.

## 5. Open the ports

On the instance page → **Networking** tab (or **Primary VNIC**) → click the **subnet** →
**Security** → the **Default Security List** → **Security rules** → **Add Ingress Rules**:

| Source CIDR | IP protocol | Destination port |
|---|---|---|
| `0.0.0.0/0` | TCP | `80` |
| `0.0.0.0/0` | TCP | `443` |

Optional, tighter: edit the existing port **22** rule and set its source to your home IP as `x.x.x.x/32`
(find it at <https://ifconfig.me>). If your home IP changes, SSH stops until you edit the rule again,
so skip this if your ISP changes it often; the key alone already protects SSH.

The VM's own firewall (iptables) is opened by my setup script; nothing to do there.

## 6. Check you can log in

```bash
ssh -i ~/.ssh/reelbrain_oracle ubuntu@<public IP>
```

Type `yes` to the fingerprint question. You should see an `ubuntu@reelbrain` prompt; type `exit`.

## 7. DuckDNS name

1. Go to <https://www.duckdns.org>, sign in (Google or GitHub).
2. Under **domains**, type a name, e.g. `reelbrain-mahmoud` → **add domain**.
3. In the **current ip** box next to it, paste the VM's public IP → **update ip**.

Your address is now `https://reelbrain-mahmoud.duckdns.org` (HTTPS starts working after my setup).

## 8. Firebase service-account key

1. <https://console.firebase.google.com> → **reelbrain-dev** → ⚙ **Project settings** → **Service accounts**.
2. **Firebase Admin SDK** → **Generate new private key** → **Generate key**. A JSON file downloads.
3. Move it **outside the repo**, e.g. `C:\Users\Sarah Tarek\.secrets\reelbrain-sa.json`.
   It is a password for your database: never commit it, never paste its contents into chat.

## 9. Send me

- the VM's public IP (user is `ubuntu`)
- the key path (`C:\Users\Sarah Tarek\.ssh\reelbrain_oracle` if you used step 3 as written)
- your DuckDNS name
- the service-account JSON path

Then I install Docker and Caddy, put the Gemini key and the JSON on the VM (root-only), start the
backend, point the app at the new address and do a real save from your phone.
