# Testers Guide

## Getting the Latest Dev Version

The `dev` branch has all the new cool stuff that needs testing before we merge it to `rc`. It's where we test new features, bug fixes, and stability before releasing.

### Setting Up Dev Branch

#### First-timers:

1. Clone it:

   ```bash
   git clone https://github.com/DENv-Project/DENv.git
   cd DENv
   ```

2. Switch to dev:
   ```bash
   git checkout dev
   ```

#### Already have the repo?

1. Make sure master is current branch:

   ```bash
   git checkout master
   git pull
   ```

2. Get the dev goodies:
   ```bash
   git fetch origin dev
   git checkout dev
   git pull origin dev
   ```

### Running Dev Version

Just follow the README.md or use the install script:

1. Full install:

   ```bash
   ./install.sh
   ```

2. Just restore dotfiles:

   ```bash
   ./install.sh -r
   ```

3. Other cool stuff you can do:
   ```bash
   Usage: ./install.sh [options]
            i : [i]nstall hyprland without configs
            d : install hyprland [d]efaults without configs --noconfirm
            r : [r]estore config files
            s : enable system [s]ervices
            n : ignore/[n]o [n]vidia actions
            h : re-evaluate S[h]ell
            m : no the[m]e reinstallations
            t : [t]est run without executing (-irst to dry run all)
   ```

## Testing the Release Candidate (RC) Branch

The `rc` (release-candidate) branch is used for final testing and bug fixes before a new release. During Freeze Week, only bug fixes and stabilization are allowed in `rc`—no new features. Testing on `rc` helps ensure a stable release.

### Checking Out the RC Branch

#### First-timers:

1. Clone the repo (if you haven't already):

   ```bash
   git clone https://github.com/DENv-Project/DENv.git
   cd DENv
   ```

2. Switch to the rc branch:
   ```bash
   git checkout rc
   ```

#### Already have the repo?

1. Make sure your repo is up to date:

   ```bash
   git checkout master
   git pull
   ```

2. Fetch and switch to the latest rc branch:
   ```bash
   git fetch origin rc
   git checkout rc
   git pull origin rc
   ```

### Running the RC Version

Follow the same steps as for `dev` (see above) to install and test. Focus on finding bugs and verifying stability—no new features should be present in `rc`.

> **Note:** If you find a bug in `rc`, report it right away so it can be fixed before release! See the reporting section below.

## What to Test

Look out for:

1. **New Features**: Break 'em if you can
2. **UI Elements**: Do they look right? Work right?
3. **Theme Switching**: Dark/light mode working?
4. **Wallpapers**: Can you add/remove/switch?
5. **System Features**: Notifs, settings working?
6. **Stability**: Any crashes or freezes?
7. **Different Systems**: Test on whatever hardware you've got

## Testing Goals

### Focus On

- **Isolated Issues**: Pinpoint exactly where stuff breaks
- **Regression**: Make sure we didn't break old fixes
- **UX**: Tell us if something feels clunky
- **Performance**: Spot any lag or resource hogs

### For Our Trusted Testers

As a trusted tester, you're extra special:

- You get quick answers when you report stuff
- Your ideas go to the top of the pile
- Just say what you think - no filter needed
- Help us shape features before everyone else sees them

We'll get back to you fast so we can fix things quicker!

## How to Report Issues

Found something weird? Here's what to do:

### GitHub (Preferred)

Report directly on the rc to master MR:

- Go here: https://github.com/DENv-Project/DENv/compare/master...rc

Report directly on the dev to rc MR:

- Go here: https://github.com/DENv-Project/DENv/compare/dev...rc


### Discord

In the DENv Discord:

- Drop a message in #testers channel
- Real issues should go on GitHub, but we can chat about them in Discord

### Making Good Bug Reports

Just follow the [issue templates](.github/ISSUE_TEMPLATE)

## Release Schedule

Check the [release policy](./RELEASE_POLICY.md)

## Community Stuff

Nobody gets paid for this - we're all just nerds who like making cool stuff together. Your help testing is super valuable! Everyone's contribution matters, whether it's testing, bug reports, code, or just ideas.

Let's build something awesome together! Thanks for being part of our weird little community!

### Do not forget stay DENvrated!
