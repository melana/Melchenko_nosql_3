// 1. Топ-10 найпопулярніших фільмів (супервузли серед Movie)

MATCH (m:Movie)<-[r:RATED]-()
RETURN m.movieId AS movieId, 
       m.title AS title, 
       count(r) AS degree
ORDER BY degree DESC
LIMIT 10;


// 2. Топ-10 найактивніших користувачів (супервузли серед User)

MATCH (u:User)-[r:RATED]->()
RETURN u.userId AS userId, 
       u.gender AS gender, 
       u.age AS age, 
       count(r) AS degree
ORDER BY degree DESC
LIMIT 10;


// 3. Аналіз жанрових супервузлів (зв'язки IN_GENRE)

MATCH (g:Genre)<-[r:IN_GENRE]-(m:Movie)
RETURN g.name AS genre, 
       count(r) AS connectedMoviesCount
ORDER BY connectedMoviesCount DESC;


// Оптимізований пошук супервузлів через APOC degree

MATCH (n)
WHERE n:Movie OR n:User OR n:Genre
RETURN labels(n)[0] AS nodeType,
       coalesce(n.title, "User " + toString(n.userId), n.name) AS nodeIdentifier,
       apoc.node.degree(n) AS totalDegree
ORDER BY totalDegree DESC
LIMIT 15;
