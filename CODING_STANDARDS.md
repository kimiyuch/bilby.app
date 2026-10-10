# Coding standards

Read during review.

- Clock and time logic (counting down, catching up, events, when to tick) belongs in BilbyKit, with tests. The
  browser version in bilby.web ports it to `resources/js/play/kit` with ported tests; a change on one side needs
  the same change and test on the other. Views and stores only call it.
