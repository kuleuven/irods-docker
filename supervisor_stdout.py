from __future__ import print_function
import sys

def main():
    with open('/proc/1/fd/1', mode='w', encoding='utf-8') as o:
        while 1:
            sys.stdout.write('READY\n') # transition from ACKNOWLEDGED to READY
            sys.stdout.flush()
            line = sys.stdin.readline()  # read header line from stdin
            headers = dict([ x.split(':') for x in line.split() ])
            data = sys.stdin.read(int(headers['len'])) # read the event payload
            handle(headers, data, o)
            sys.stdout.write("RESULT 2\nOK")
            sys.stdout.flush()

def handle(event, response, o):
    line, data = response.split('\n', 1)
    headers = dict([ x.split(':') for x in line.split() ])
    lines = data.split('\n')
    prefix = '%s %s | '%(headers['processname'], headers['channel'])
    o.write('\n'.join([ prefix + l for l in lines if l.strip() != '' ]) + '\n')
    o.flush()

if __name__ == '__main__':
    main()
