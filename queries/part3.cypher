// Запит 1. Фільми жанру «Thriller» із середнім рейтингом вище 4.0

MATCH (m:Movie)-[:IN_GENRE]->(g:Genre {name: 'Thriller'})
MATCH (u:User)-[r:RATED]->(m)
WITH m, avg(r.rating) AS avgRating, count(r) AS ratingCount
WHERE avgRating > 4.0
RETURN m.movieId AS movieId, 
       m.title AS title, 
       m.year AS year, 
       round(avgRating, 2) AS avgRating, 
       ratingCount
ORDER BY avgRating DESC;



// Запит 2. Користувачі, які поставили оцінку 5 більш ніж 50 фільмам

MATCH (u:User)-[r:RATED {rating: 5}]->(m:Movie)
WITH u, count(r) AS count5StarRatings
WHERE count5StarRatings > 50
RETURN u.userId AS userId, 
       u.gender AS gender, 
       u.age AS age, 
       count5StarRatings
ORDER BY count5StarRatings DESC;


// Запит 3. Спільні фільми з високою оцінкою (рейтинг >= 4) для двох користувачів

MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User {userId: 2})
WHERE r1.rating >= 4 AND r2.rating >= 4
RETURN m.movieId AS movieId, 
       m.title AS title, 
       m.year AS year, 
       r1.rating AS ratingUser1, 
       r2.rating AS ratingUser2
ORDER BY m.title;


// Запит 4. Статистика оцінок по жанрах (середній рейтинг та кількість оцінок)

MATCH (g:Genre)<-[:IN_GENRE]-(m:Movie)<-[r:RATED]-(:User)
WITH g, avg(r.rating) AS avgRating, count(r) AS totalRatings, count(DISTINCT m) AS totalMovies
RETURN g.name AS genre, 
       round(avgRating, 2) AS avgRating, 
       totalRatings, 
       totalMovies
ORDER BY avgRating DESC;


// Запит 5. Рекомендаційна система (Collaborative Filtering)
// Фільми, які ще не бачив користувач (userId=1), але високо оцінили схожі користувачі

MATCH (u1:User {userId: 1})-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE u1 <> u2 AND r1.rating >= 4 AND r2.rating >= 4
WITH DISTINCT u1, u2
MATCH (u2)-[r3:RATED]->(recMovie:Movie)
WHERE r3.rating >= 4 AND NOT (u1)-[:RATED]->(recMovie)
RETURN recMovie.movieId AS movieId, 
       recMovie.title AS title, 
       recMovie.year AS year, 
       count(DISTINCT u2) AS recommendedByUsersCount, 
       round(avg(r3.rating), 2) AS avgRatingBySimilarUsers
ORDER BY recommendedByUsersCount DESC, avgRatingBySimilarUsers DESC
LIMIT 10;


// Запит 6. Найкоротший ланцюжок зв'язку між двома користувачами (userId=1 та userId=2)

MATCH (u1:User {userId: 1}), (u2:User {userId: 2})
MATCH p = shortestPath((u1)-[:RATED*..10]-(u2))
RETURN [node IN nodes(p) | COALESCE(node.title, "User " + node.userId)] AS connectionChain,
       length(p) AS pathLength;
