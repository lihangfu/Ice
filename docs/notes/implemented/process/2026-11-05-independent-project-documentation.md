# Agent Note: Independent project documentation

Status: implemented

## Problem

Inherited promotion, roadmap promises and support links direct users away from
this project's independently maintained behavior and releases.

## Decision

README owns a single source attribution and describes this project's current
features, installation, build and release contracts. Inherited screenshots and
unimplemented roadmap entries are removed rather than presented as current
product evidence or commitments.

Issue templates and the About pane direct contributions and bug reports to this
repository. Donation links and the inherited funding configuration are removed.
The code of conduct refers to this project's maintainer.

## Alternatives considered

- Retain inherited promotion and roadmap entries with a fork disclaimer: users
  would still see unrelated support channels and development commitments.
- Replace every inherited identifier and attribution: copyright notices still
  describe the inherited work, and changing the bundle identifier would affect
  preferences and macOS permissions without serving this documentation change.

## Consequences

The GPL license, existing copyright notices and third-party acknowledgements
remain. The bundle identifier is retained for installation compatibility.
Future screenshots and roadmap entries need evidence or decisions from this
project. Build and release instructions remain owned by README.
