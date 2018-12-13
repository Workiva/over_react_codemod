install:
	pip install -r requirements_dev.txt

test:
	nosetests tests

dist:
	pyinstaller --onefile bin/over_react_migrate_to_dart1_and_dart2.py
	# pyinstaller --onefile bin/over_react_migrate_to_dart2.py

.PHONY: install test dist
