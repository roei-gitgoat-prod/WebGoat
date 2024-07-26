# ruleid: sqlalchemy-sql-injection
def function(var):
    query = cls.query.group_by(
        "oops{}".format(var)
    )
