import 'package:shared_preferences/shared_preferences.dart';

class FavoritesService {
static const _key = 'favorites';
final SharedPreferences _prefs;

FavoritesService(this._prefs);

Set get favorites =>
_prefs.getStringList(_key)?.toSet() ?? {};

bool isFavorite(String id) => favorites.contains(id);

Future toggleFavorite(String id) async {
final favs = favorites;
if (favs.contains(id)) favs.remove(id);
else favs.add(id);
await _prefs.setStringList(_key, List<String>.from(favs));

}
}