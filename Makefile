init:
	pip install -r requirements_dev.txt

test:
	nosetests tests

.PHONY: init test
