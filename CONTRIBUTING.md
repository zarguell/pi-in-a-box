# Contributing to pi-in-a-box

Thanks for your interest in contributing.

## Getting started

1. Fork and clone the repository.
2. Copy `.env.example` to `.env` and configure your provider keys.
3. Run `docker compose up -d --build` to start the stack.
4. Open `http://127.0.0.1:8000` in your browser.

## Development workflow

- Test changes by rebuilding: `docker compose up -d --build`
- Run the smoke test: `docker compose exec pi-in-a-box bash /usr/local/bin/pi-in-a-box-doctor`
- Run the full smoke suite: `bash scripts/smoke-test.sh`

## Pull requests

- Keep changes focused: one feature or fix per PR.
- Test locally before submitting.
- Update documentation if behavior changes.
- CI must pass before merge.

## Reporting issues

Open an issue with:
- Steps to reproduce
- Expected vs. actual behavior
- Container logs (`docker compose logs pi-in-a-box`)

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
