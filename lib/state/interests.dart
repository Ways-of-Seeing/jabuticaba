/// Interesses escolhidos no onboarding. Cada um vira hashtags (Mastodon,
/// Pixelfed, Loops), termos de busca (PeerTube, Lemmy, feeds do Bluesky) e
/// categorias de servidor.
class Interest {
  const Interest(
    this.id,
    this.label,
    this.emoji, {
    required this.tags,
    required this.query,
    this.category,
  });

  final String id;
  final String label;
  final String emoji;
  final List<String> tags;
  final String query;
  final String? category;
}

const interests = <Interest>[
  Interest(
    'arte',
    'Arte',
    '🎨',
    tags: ['art', 'mastoart', 'arte'],
    query: 'art',
    category: 'art',
  ),
  Interest(
    'foto',
    'Fotografia',
    '📷',
    tags: ['photography', 'fotografia'],
    query: 'photography',
  ),
  Interest(
    'tech',
    'Tecnologia',
    '💻',
    tags: ['tech', 'opensource', 'linux'],
    query: 'technology',
    category: 'tech',
  ),
  Interest(
    'musica',
    'Música',
    '🎧',
    tags: ['music', 'musica'],
    query: 'music',
    category: 'music',
  ),
  Interest(
    'games',
    'Games',
    '🎮',
    tags: ['gaming', 'indiegames'],
    query: 'gaming',
    category: 'games',
  ),
  Interest(
    'ciencia',
    'Ciência',
    '🔭',
    tags: ['science', 'ciencia'],
    query: 'science',
    category: 'academia',
  ),
  Interest(
    'natureza',
    'Natureza',
    '🌿',
    tags: ['nature', 'birds', 'natureza'],
    query: 'nature',
  ),
  Interest(
    'comida',
    'Comida',
    '🍲',
    tags: ['food', 'cooking', 'receitas'],
    query: 'cooking',
    category: 'food',
  ),
  Interest(
    'livros',
    'Livros',
    '📚',
    tags: ['books', 'bookstodon', 'livros'],
    query: 'books',
    category: 'books',
  ),
  Interest(
    'cinema',
    'Cinema e séries',
    '🎬',
    tags: ['film', 'movies', 'cinema'],
    query: 'movies',
  ),
  Interest(
    'humor',
    'Humor',
    '😂',
    tags: ['humor', 'memes', 'funny'],
    query: 'funny',
  ),
  Interest(
    'politica',
    'Política',
    '🗳️',
    tags: ['politics', 'politica'],
    query: 'politics',
    category: 'activism',
  ),
  Interest(
    'brasil',
    'Brasil',
    '🇧🇷',
    tags: ['brasil', 'brazil'],
    query: 'brasil',
    category: 'regional',
  ),
  Interest(
    'esportes',
    'Esportes',
    '⚽',
    tags: ['football', 'futebol', 'sports'],
    query: 'football',
    category: 'sports',
  ),
  Interest(
    'lgbt',
    'LGBTQIA+',
    '🏳️‍🌈',
    tags: ['lgbtqia', 'pride'],
    query: 'lgbt',
    category: 'lgbt',
  ),
  Interest(
    'bichos',
    'Bichos',
    '🐈',
    tags: ['caturday', 'dogsofmastodon', 'cats'],
    query: 'cats',
  ),
  Interest(
    'espaco',
    'Espaço',
    '🚀',
    tags: ['space', 'astronomy'],
    query: 'space',
  ),
  Interest(
    'design',
    'Design',
    '✏️',
    tags: ['design', 'illustration'],
    query: 'design',
    category: 'art',
  ),
  Interest(
    'viagem',
    'Viagens',
    '🧭',
    tags: ['travel', 'viagem'],
    query: 'travel',
  ),
  Interest(
    'diy',
    'Faça você mesmo',
    '🪚',
    tags: ['diy', 'maker', 'crafts'],
    query: 'diy',
    category: 'hobby',
  ),
];

Interest? interestById(String id) {
  for (final i in interests) {
    if (i.id == id) return i;
  }
  return null;
}
