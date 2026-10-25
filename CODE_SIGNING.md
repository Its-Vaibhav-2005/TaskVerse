# Code signing policy

## Current status

TrackVerse's Windows installers through 1.3.0 are unsigned. The free
SignPath Foundation application was submitted on 2026-10-24; approval and
Electron artifact coverage remain pending. No SignPath signature has been issued.
Version 1.3.0 is distributed unsigned because signing credentials are not
configured on the build host and may still
be blocked by Smart App Control. Microsoft file-review submissions are not
code-signing approval or a guarantee that Windows will allow execution.

TrackVerse's own source code is [MIT licensed](LICENSE). Third-party software
and fonts retain their original licenses and notices.

## Responsible team

- Author, maintainer, and reviewer: [Vaibhav Pandey / Its-Vaibhav-2005](https://github.com/Its-Vaibhav-2005).
- Signing approver: the same maintainer, after reviewing the release and its
  build provenance. Signing credentials must not be available to untrusted code.

## Intended free signing process

If approved, SignPath integration will use source-verifiable builds and manual
release approval. The maintainer must confirm multi-factor authentication for
the repository and signing account during enrollment. Signing policy and
publisher attribution will be updated when the Foundation approves the project.
The required attribution on approved releases will be:

> Free code signing provided by SignPath.io, certificate by SignPath Foundation.

SignPath's rules restrict signing of upstream binaries. TrackVerse must clarify
coverage for its Electron runtime and obtain trusted upstream signatures where
necessary. An installer signature alone is insufficient evidence that every
bundled binary can run under Smart App Control. The existing signature audit
must continue to reject incomplete coverage.

## Privacy

See the [privacy policy](https://its-vaibhav-2005.github.io/TaskVerse/privacy.html).
Habit data stays local unless the user enables Google backup. Google services
are subject to [Google's privacy policy](https://policies.google.com/privacy).

## Provider

- [Free signing application](https://signpath.org/apply)
- [Foundation requirements](https://signpath.org/terms)

Keep Windows protections enabled. A signature verifies publisher and file
integrity; it is not a guarantee that the application has no vulnerabilities.
