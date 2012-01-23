# vacuum.rb

This is an example of use [couchbase gem][1]. The application is
listening for (uses [rev][2] to listen efficiently) given directory and
try to add all new files to the database. The files should be valid JSON
document (otherwise script reports an error and deletes the file) and
contain `_id` key which will be used as key.

## Setup

Clone repository:

    $ git clone git://github.com/avsej/vacuum.rb.git

Install dependencies, using bundler (see [couchbase gem README file][3]
for installation details):

    $ cd vacuum.rb
    $ bundle install


## Usage

To show available options run script with `-?` argument:

    $ ./vacuum.rb -?
    Usage: vacuum.rb [options]
        -v, --[no-]verbose               Run verbosely
        -h, --hostname HOSTNAME          Hostname to connect to (default: )
        -u, --user USERNAME              Username to log with (default: none)
        -p, --passwd PASSWORD            Password to log with (default: none)
        -b, --bucket NAME                Name of the bucket to connect to (default: default)
        -s, --spool-directory DIRECTORY  Location of spool directory (default: /var/spool/vacuum)
        -?, --help                       Show this message

To listen `/tmp/couchbase-input` and store it on `dropbox` bucket on cluster
`http://example.com:8091` use the following command:

    $ ./vacuum.rb -s /tmp/couchbase-input -b dropbox -h example.com:8091

[1]: https://rubygems.org/gems/couchbase
[2]: https://rubygems.org/gems/rev
[3]: https://github.com/couchbase/couchbase-ruby-client#readme
