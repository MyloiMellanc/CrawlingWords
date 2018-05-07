from urllib.parse import quote
#from selenium import webdriver
from neo4j.v1 import GraphDatabase, basic_auth

import requests
from bs4 import BeautifulSoup
import re
from time import sleep


class HelloWorldExample(object):

    def __init__(self, uri, user, password):
        self._driver = GraphDatabase.driver(uri, auth=(user, password))

    def close(self):
        self._driver.close()

    def creating(self, word1, word2):
        with self._driver.session() as session:
            session.write_transaction(self._create_and_return, word1, word2)

    @staticmethod
    def _create_and_return(tx, word1, word2):
        query = "MATCH (a:Base), (b:Base) WHERE a.Name=\'" + word1 + "\' AND b.Name=\'" + word2 + "\' MERGE (a)-[r:WikiLine]->(b) RETURN r"
        result = tx.run(query)


    def marking(self, word):
        with self._driver.session() as session:
            session.write_transaction(self._mark, word)


    @staticmethod
    def _mark(tx, word):
        query = "MATCH (a:Base) WHERE a.Name=\'" + word + "\' SET a.Wiki=true RETURN a"
        result = tx.run(query)

    def get_words(self):
        with self._driver.session() as session:
            return session.read_transaction(self.match_single_nodes)

    @staticmethod
    def match_single_nodes(tx):
        result = tx.run("MATCH (a:Base) WHERE NOT (a)-[]-(:Base) AND a.Wiki=false WITH a, rand() AS number RETURN a.Name ORDER BY number LIMIT 300")
        return [record["a.Name"] for record in result]



def createRelation(db, word1, word2):
    r = createRelation.hangul.sub(' ',word2)
    result = r.split()

    for i in result:
        db.creating(word1,i)



createRelation.hangul = re.compile('[^\u3131-\u3163\uac00-\ud7a3]+')



uri = "bolt://192.168.0.13:7687/db/data/"

DB = HelloWorldExample(uri, "neo4j", "flrndnqk23")

words = DB.get_words()

count = 1
for word in words:
    sleep(0.5)
    print("SEARCH " + str(count) + " : "+word)
    count = count + 1
    url = "https://namu.wiki/w/" + quote(word)
    req = requests.get(url)
    html = req.text
    soup = BeautifulSoup(html, 'html.parser')
    words1 = soup.find("div", {"class" : "wiki-category"})
    if words1 is not None:
        categories = words1.findAll("li")
        for i in categories:
            createRelation(DB, word, i.text)
    words2 = soup.findAll("a", {"class" : "wiki-link-internal"})
    for i in words2:
        target = i["title"]
        createRelation(DB,word,target)
    DB.marking(word)




