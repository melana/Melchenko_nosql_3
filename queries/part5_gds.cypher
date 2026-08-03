// 5.1. PageRank на графі фільмів

// Крок 1: Матеріалізуємо ребра фільм-фільм через спільних користувачів
MATCH (m1:Movie)<-[r1:RATED]-(u:User)-[r2:RATED]->(m2:Movie)
WHERE r1.rating >= 5 AND r2.rating >= 5 AND id(m1) < id(m2)
WITH m1, m2, count(u) AS weight
WHERE size([(m1)<-[:RATED]-() | 1]) > 20
  AND size([(m2)<-[:RATED]-() | 1]) > 20
WITH m1, m2, weight
ORDER BY weight DESC
LIMIT 30000
MERGE (m1)-[co:CO_RATED]-(m2)
SET co.weight = weight;

// Крок 2: Створюємо проєкцію
CALL gds.graph.project(
  'movieGraph',
  'Movie',
  { CO_RATED: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 3: Запуск алгоритму PageRank із врахуванням ваги ребер
CALL gds.pageRank.stream('movieGraph', {
  maxIterations: 20,
  dampingFactor: 0.85,
  relationshipWeightProperty: 'weight'
})
YIELD nodeId, score
RETURN gds.util.asNode(nodeId).movieId AS movieId,
       gds.util.asNode(nodeId).title AS title,
       round(score, 4) AS pageRankScore
ORDER BY pageRankScore DESC
LIMIT 10;

// Крок 4: Видаляємо проєкцію та тимчасові ребра
CALL gds.graph.drop('movieGraph') YIELD graphName;
MATCH ()-[co:CO_RATED]-() DELETE co;


// 5.2. Виявлення спільнот (Louvain)

// Крок 1: Матеріалізуємо ребра користувач-користувач через спільні фільми
MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating >= 5 AND r2.rating >= 5 AND id(u1) < id(u2)
WITH u1, u2, count(m) AS weight
WITH u1, u2, weight
ORDER BY weight DESC
LIMIT 30000
MERGE (u1)-[sim:SIMILAR]-(u2)
SET sim.weight = weight;

// Крок 2: Створюємо проєкцію
CALL gds.graph.project(
  'userSimilarity',
  'User',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 3: Запуск алгоритму Louvain та збереження communityId у вузли користувачів
CALL gds.louvain.write('userSimilarity', {
  writeProperty: 'communityId',
  relationshipWeightProperty: 'weight'
})
YIELD communityCount, modularity;

// Крок 4.1: Топ-10 найбільших кластерів користувачів
MATCH (u:User)
WHERE u.communityId IS NOT NULL
RETURN u.communityId AS communityId, count(u) AS clusterSize
ORDER BY clusterSize DESC
LIMIT 10;

// Крок 4.2: Аналіз ТОП-3 жанрів для найбільших кластерів
MATCH (u:User)
WHERE u.communityId IS NOT NULL
WITH u.communityId AS communityId, count(u) AS clusterSize
ORDER BY clusterSize DESC
LIMIT 5
MATCH (u:User {communityId: communityId})-[r:RATED]->(m:Movie)-[:IN_GENRE]->(g:Genre)
WHERE r.rating >= 4
WITH communityId, clusterSize, g.name AS genre, count(r) AS genreRatingsCount
ORDER BY genreRatingsCount DESC
WITH communityId, clusterSize, collect({genre: genre, count: genreRatingsCount})[0..3] AS top3Genres
UNWIND top3Genres AS gInfo
RETURN communityId,
       clusterSize,
       gInfo.genre AS genre,
       gInfo.count AS genreRatingsCount
ORDER BY clusterSize DESC, genreRatingsCount DESC;

// Крок 5: Видаляємо проєкцію та тимчасові ребра
CALL gds.graph.drop('userSimilarity') YIELD graphName;
MATCH ()-[sim:SIMILAR]-() DELETE sim;


// 5.3. Найкоротший шлях між користувачами (Dijkstra)

// Крок 1: Матеріалізуємо ребра SIMILAR та проєкцію заново
MATCH (u1:User)-[r1:RATED]->(m:Movie)<-[r2:RATED]-(u2:User)
WHERE r1.rating >= 5 AND r2.rating >= 5 AND id(u1) < id(u2)
WITH u1, u2, count(m) AS weight
WITH u1, u2, weight
ORDER BY weight DESC
LIMIT 30000
MERGE (u1)-[sim:SIMILAR]-(u2)
SET sim.weight = weight;

CALL gds.graph.project(
  'userGraph',
  'User',
  { SIMILAR: { orientation: 'UNDIRECTED', properties: 'weight' } }
)
YIELD graphName, nodeCount, relationshipCount;

// Крок 2: Пошук найкоротшого шляху Дейкстри між користувачами
MATCH (source:User {userId: 3285}), (target:User {userId: 2185})
CALL gds.shortestPath.dijkstra.stream('userGraph', {
    sourceNode: source,
    targetNode: target,
    relationshipWeightProperty: 'weight'
})
YIELD index, sourceNode, targetNode, totalCost, nodeIds, costs
RETURN index,
       totalCost,
       [nodeId IN nodeIds | "User " + toString(gds.util.asNode(nodeId).userId)] AS path,
       size(nodeIds) - 1 AS pathLength;

// Крок 3: Очищення проєкції та ребер
CALL gds.graph.drop('userGraph') YIELD graphName;
MATCH ()-[sim:SIMILAR]-() DELETE sim;
