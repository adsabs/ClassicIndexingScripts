#!/bin/sh

dir=/proj/adswon/soft/abs/absload/index/dev/test_text_parser
/proj/ads/www/cgi/bin/linux/maint/cleanup -u -a -i -s -c -b -t $dir/text.trans -S $dir/text.kill -C $dir/text.kill_sens 
