# Changelog

## v1.4.1 - Apr 25, 2023

* Add support for gzip compression ([#17](https://github.com/vmware/fluent-plugin-vmware-loginsight/pull/17),[#18](https://github.com/vmware/fluent-plugin-vmware-loginsight/pull/18), [@toddc-vmware](https://github.com/toddc-vmware))
* Add support for multi-worker ([#27](https://github.com/vmware/fluent-plugin-vmware-loginsight/pull/27),[@yajith](https://github.com/yajith))
* Update default batch size to 4MB from 512KB ([#28](https://github.com/vmware/fluent-plugin-vmware-loginsight/pull/28), [@mohitevishal](https://github.com/mohitevishal))

## v1.4.0 - Mar 07, 2023

* Base Photon image has been updated to photon:4.0-20230227
* Log Insight has been changed to VMware Aria Operations For Logs

## v1.3.1 - Nov 01, 2022

* Based Photon image has been updated to photon:4.0-20221029

## v1.3.0 - July 29, 2022

* Added buffering support which allows sending out logs in chunks rather than one by one 

## v1.0.0 - April 20, 2021

* Update plugin structure to use Fluentd 1.x syntax

## v0.1.11 - March 31, 2021

* Add an option to rename Loginsight fields. This option could be used to rename certain fields that are reserved by Loginsight

## v0.1.10 - May 13, 2020

* Escape `@` char from Loginsight field

## v0.1.9 - May 07, 2020

* No change

## v0.1.8 - May 06, 2020 yanked, Not available

* Parameterize and add an option to shorten Loginsight field names

## v0.1.7 - December 10, 2019

* Fix basic authentication #8

## v0.1.6 - September 13, 2019

* For immutable log fields, use a copy to utf encode. This should fix 'can't modify frozen String' error in #5

## v0.1.5 - October 22, 2018

* Add option to display debug logs for http connection, default false
* Flatten Lists/Arrays for LI fields
* Convert LI field value to String to ensure no utf encoding errors
* Update help doc/examples with sample use of @log_text_keys and @http_conn_debug options

## v0.1.4 - October 17, 2018

* Add option to specify a list of keys that plugin should treat as log messages and forward them as text to Loginsight. Plugin should not flatten these fields
* If user specifies flatten_hashes option as false, plugin should try to add record key/values as is

## v0.1.3 - September 13, 2018

* Reorder namespace and name fields to be shorten

## v0.1.2 - September 10, 2018

* Republished yanked gem

## v0.1.1 - August 30, 2018 yanked, Not available

* Send log messages in batches, add max_batch_size parameter
* Shorten common kubernetes Loginsight field names
* Convert time to milliseconds


## 0.1.0 - August 30, 2018

### Initial release

* Fluentd output plugin to push logs to VMware Log Insight

