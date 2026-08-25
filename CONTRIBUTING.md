# Contributing to DeepWork

Thanks for helping improve DeepWork.

## Development workflow

1. Create a focused branch from `main`.
2. Make the smallest change that solves the problem.
3. Add or update tests when behavior changes.
4. Run the unit and UI tests in Xcode before opening a pull request.
5. Describe what changed and how it was tested.

Please do not commit Xcode user settings, build products, provisioning
profiles, signing certificates, API keys, or other private credentials.

## Pull requests

Keep pull requests focused and explain any behavior or UX trade-offs. Changes
to motion thresholds should include detector tests and, where possible, notes
about the device conditions used to validate them.

## Code style

Use Swift's standard formatting and the existing UIKit patterns in the
project. Prefer clear names and small, testable types over clever abstractions.
