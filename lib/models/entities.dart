class User {
  User(
    this.email,
    this.name,
    this.password, {
    this.id = '',
    this.about = '',
    this.avatar = '',
    this.verified = false,
  });
  String email, name, password, id, about, avatar;
  bool verified;
  Map<String, dynamic> j() => {
    'e': email,
    'n': name,
    'p': password,
    'a': about,
    'v': avatar,
    'ok': verified,
    'id': id,
  };
  factory User.f(Map x) => User(
    x['e'],
    x['n'],
    x['p'],
    about: x['a'] ?? '',
    avatar: x['v'] ?? '',
    verified: x['ok'] ?? false,
  )..id = x['id'] ?? '';
}

class Invite {
  Invite(this.from, this.to);
  String from, to;
  Map<String, dynamic> j() => {'f': from, 't': to};
  factory Invite.f(Map x) => Invite(x['f'], x['t']);
}

class Message {
  Message(
    this.id,
    this.sender,
    this.body,
    this.when, {
    this.type = 'text',
    this.status = 'sent',
    this.edited = false,
    this.media = '',
  });
  String id, sender, body, when, type, status, media;
  bool edited;
  Map<String, dynamic> j() => {
    'i': id,
    's': sender,
    'b': body,
    'w': when,
    't': type,
    'd': status,
    'e': edited,
    'z': media,
  };
  factory Message.f(Map x) => Message(
    x['i'],
    x['s'],
    x['b'],
    x['w'],
    type: x['t'] ?? 'text',
    status: x['d'] ?? 'sent',
    edited: x['e'] ?? false,
    media: x['z'] ?? '',
  );
}

class Chat {
  Chat(
    this.id,
    this.members,
    this.messages, {
    this.archived = false,
    this.muted = false,
  });
  String id;
  List<String> members;
  List<Message> messages;
  bool archived, muted;
  Map<String, dynamic> j() => {
    'i': id,
    'm': members,
    'x': messages.map((x) => x.j()).toList(),
    'a': archived,
    'u': muted,
  };
  factory Chat.f(Map x) => Chat(
    x['i'],
    List<String>.from(x['m']),
    (x['x'] as List).map((e) => Message.f(e)).toList(),
    archived: x['a'] ?? false,
    muted: x['u'] ?? false,
  );
}

class Data {
  Data({
    required this.users,
    required this.chats,
    required this.invites,
    this.active,
  });
  List<User> users;
  List<Chat> chats;
  List<Invite> invites;
  String? active;
  User get me => users.firstWhere((x) => x.email == active);
  Map<String, dynamic> j() => {
    'u': users.map((x) => x.j()).toList(),
    'c': chats.map((x) => x.j()).toList(),
    'i': invites.map((x) => x.j()).toList(),
    'a': active,
  };
  factory Data.f(Map x) => Data(
    users: (x['u'] as List).map((e) => User.f(e)).toList(),
    chats: (x['c'] as List).map((e) => Chat.f(e)).toList(),
    invites: (x['i'] as List).map((e) => Invite.f(e)).toList(),
    active: x['a'],
  );
}
