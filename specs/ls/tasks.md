# Tasks: ls

- [x] 1. Parse GNU options: `-a -A -1 -C -R -F -r -d`, long options with
      prefixes, `--classify[=WHEN]`, `--`, permutation
  - _Requirements: 2.4, 3.5, 5.1, 5.2, 5.3_
- [x] 2. Gather operands: files vs directories, missing operands and their
      messages, dangling links
  - _Requirements: 1.1, 1.2, 1.4, 1.5, 2.5_
- [x] 3. List a directory: hidden-entry rules, byte-order sort, -r, headers
      and blank lines
  - _Requirements: 1.3, 2.1, 2.2, 2.3, 3.1, 3.2_
- [x] 4. Port GNU's column layout for -C, with `COLUMNS` handling
  - _Requirements: 3.3, 3.4_
- [x] 5. Derive file kinds without stat(): dangling links, links to
      directories; -F indicators
  - _Requirements: 4.1, 4.2_
- [x] 6. Recursion with -R, depth first, not following detected links
  - _Requirements: 4.3_
- [x] 7. Exit statuses 0/1/2
  - _Requirements: 5.4_
- [x] 8. Unit tests and end-to-end tests of the native binary
  - _Requirements: all_
