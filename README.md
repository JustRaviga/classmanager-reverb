# classmanager-reverb

Minimal Laravel skeleton that runs the Classmanager Reverb (WebSocket) host.

This repository is cloned by the EC2 Image Builder pipeline defined in
[`JustRaviga/classmanager`](https://github.com/JustRaviga/classmanager)
(`backend/infrastructure/serverless/resources/reverb.yml`) and baked into a
self-contained AMI. The instances launched from that AMI run:

```
php artisan reverb:start --host=0.0.0.0 --port=8080
```

via a systemd unit installed at AMI build time. Runtime configuration
(`APP_KEY`, `REVERB_APP_KEY`, `REVERB_APP_SECRET`, Redis endpoint, etc.) is
written to `/etc/reverb/env` by the EC2 UserData script and loaded by
systemd via `EnvironmentFile=`.

Reverb is a generic Pusher-protocol message bus — channel auth and event
publishing both happen on the Lambda API side of Classmanager. This host
carries no domain code, no secrets, and no public-facing API surface. The
repo is intentionally minimal so the AMI bake is fast and the attack surface
is small. Because there is nothing sensitive here, the repo is public — the
Image Builder clones over anonymous HTTPS with no GitHub credential.

## Files

- `composer.json` / `composer.lock` — pins `laravel/framework` and
  `laravel/reverb` versions.
- `artisan` — standard Laravel CLI entry point.
- `bootstrap/app.php`, `bootstrap/providers.php` — Laravel 11+ slim
  application bootstrap. No routing, no middleware, no providers beyond
  what Reverb auto-registers.
- `config/*.php` — minimal config: `app`, `broadcasting`, `reverb`,
  `database` (Redis only), `cache` (array), `logging` (stderr).

## Updating Reverb

Bump `laravel/reverb` in `composer.json`, run `composer update
laravel/reverb`, commit the lockfile, push. The next weekly AMI bake
(Sunday 00:00 UTC) picks up the new version automatically. To roll out
sooner, trigger an Image Builder pipeline run via the AWS console or:

```
aws imagebuilder start-image-pipeline-execution --image-pipeline-arn <arn>
aws autoscaling start-instance-refresh --auto-scaling-group-name cm-<env>-reverb-asg
```

## Local development

Not intended for local development. The full Classmanager application lives
at [JustRaviga/classmanager](https://github.com/JustRaviga/classmanager).
