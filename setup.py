# -*- coding: utf-8 -*-

from setuptools import setup, find_packages


with open('README.md') as f:
    readme = f.read()

with open('LICENSE') as f:
    license = f.read()

setup(
    name='over_react_codemod',
    version='0.0.0',
    description='Codemods for upgrading over_react code to Dart 2 compatibility.',
    long_description=readme,
    author='Workiva Client Platform Team',
    author_email='clientplat@workiva.com',
    url='https://github.com/Workiva/over_react_codemod',
    license=license,
    packages=['over_react_codemod'],
    scripts=['bin/migrate_to_dart1_and_dart2.py'],
)
