--create python env
python -m venv venv
echo "venv/" >> .gitignore
venv\Scripts\activate


--create dbt profile
mkdir %userprofile%\.dbt


--dbt profile present in this dir
C:\Users\soura\.dbt