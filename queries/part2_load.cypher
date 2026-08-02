// КРОК 1: Створення унікальних обмежень (Constraints) та індексів

// Обмеження унікальності та індекс для User(userId)
CREATE CONSTRAINT user_id_unique IF NOT EXISTS
FOR (u:User) REQUIRE u.userId IS UNIQUE;

// Обмеження унікальності та індекс для Movie(movieId)
CREATE CONSTRAINT movie_id_unique IF NOT EXISTS
FOR (m:Movie) REQUIRE m.movieId IS UNIQUE;

// Обмеження унікальності та індекс для Genre(name)
CREATE CONSTRAINT genre_name_unique IF NOT EXISTS
FOR (g:Genre) REQUIRE g.name IS UNIQUE;


// КРОК 2: Завантаження вузлів

// Завантаження користувачів (User)
LOAD CSV WITH HEADERS FROM 'file:///users.csv' AS row
MERGE (u:User {userId: toInteger(row.userId)})
ON CREATE SET 
    u.gender = row.gender,
    u.age = toInteger(row.age),
    u.occupation = toInteger(row.occupation);

// Завантаження фільмів (Movie)
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
MERGE (m:Movie {movieId: toInteger(row.movieId)})
ON CREATE SET 
    m.title = row.title;

// Створення вузлів жанрів (Genre) та зв'язків [:IN_GENRE]
LOAD CSV WITH HEADERS FROM 'file:///movies.csv' AS row
MATCH (m:Movie {movieId: toInteger(row.movieId)})
WITH m, split(row.genres, '|') AS genreList
UNWIND genreList AS genreName
WITH m, trim(genreName) AS gName
WHERE gName <> ''
MERGE (g:Genre {name: gName})
MERGE (m)-[:IN_GENRE]->(g);


// КРОК 3: Батчеве завантаження ребер оцінок [:RATED] (1 мільйон записів)

CALL apoc.periodic.iterate(
  "LOAD CSV WITH HEADERS FROM 'file:///ratings.csv' AS row RETURN row",
  "MATCH (u:User {userId: toInteger(row.userId)})
   MATCH (m:Movie {movieId: toInteger(row.movieId)})
   CREATE (u)-[:RATED {
     rating: toInteger(row.rating),
     timestamp: toInteger(row.timestamp)
   }]->(m)",
  {
    batchSize: 10000,
    parallel: false,
    iterateList: true
  }
);


// ПЕРЕВІРКА РЕЗУЛЬТАТІВ ЗАВАНТАЖЕННЯ

MATCH (u:User) RETURN count(u) AS total_users;
MATCH (m:Movie) RETURN count(m) AS total_movies;
MATCH (g:Genre) RETURN count(g) AS total_genres;
MATCH ()-[r:RATED]->() RETURN count(r) AS total_ratings;
MATCH ()-[r:IN_GENRE]->() RETURN count(r) AS total_in_genre_relationships;
