import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:raidfinder/results/personal_info.dart';
import 'package:raidfinder/generator/raid_generator.dart';
import 'package:raidfinder/filter/frame_filter.dart';
import 'package:raidfinder/loader/den_loader.dart';
import 'package:raidfinder/loader/personal_loader.dart';
import 'package:raidfinder/util/game.dart';
import 'package:raidfinder/results/frame.dart';
import 'package:raidfinder/util/translator.dart';
import 'package:raidfinder/ui/filters.dart';
import 'package:raidfinder/util/settings.dart';

class Generator extends StatefulWidget {
  @override
  _GeneratorState createState() => _GeneratorState();
}

class _GeneratorState extends State<Generator> {
  int _locationDropDownValue;
  List<DropdownMenuItem<int>> _locations;
  int _denDropDownValue;
  List<DropdownMenuItem<int>> _dens;
  int _rarityDropDownValue;
  List<DropdownMenuItem<int>> _rarities;
  Game _gamesDropDownValue;
  List<DropdownMenuItem<Game>> _games;
  int _raidsDropDownValue;
  List<DropdownMenuItem<int>> _raids;

  TextEditingController _seedController;
  TextEditingController _initialFrameController;
  TextEditingController _maxResultsController;

  List<Frame> _frames;
  PersonalInfo _info;

  FilterData _data;

  @override
  void initState() {
    super.initState();

    _rarities = [
      DropdownMenuItem(value: 0, child: Text('Common')),
      DropdownMenuItem(value: 1, child: Text('Rare'))
    ];
    _rarityDropDownValue = 0;

    _games = [
      DropdownMenuItem(value: Game.Sword, child: Text('Sword')),
      DropdownMenuItem(value: Game.Shield, child: Text('Shield'))
    ];
    _gamesDropDownValue = Game.values[Settings.getInt('game') ?? 0];

    _seedController = TextEditingController();
    _seedController.text = Settings.getString('seed') ?? "0";

    _initialFrameController = TextEditingController();
    _initialFrameController.text = Settings.getString('initialFrame') ?? '1';

    _maxResultsController = TextEditingController();
    _maxResultsController.text = Settings.getString('maxResults') ?? '100';

    _locations = [
      DropdownMenuItem(value: 0, child: Text('Wild Area')),
      DropdownMenuItem(value: 1, child: Text('Isle of Armor'))
    ];
    _locationDropDownValue = 0;

    _denDropDownValue = 0;
    _raidsDropDownValue = 0;
    _dens = _createDenItems();
    _raids = _createRaidItems();

    _frames = List<Frame>();

    _data = FilterData(
        ivs: List.filled(6, -1),
        natures: List.filled(25, true),
        gender: -1,
        ability: -1,
        shiny: -1,
        skip: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(title: Text('Raid Generator')),
        body: ListView(padding: EdgeInsets.all(12.0), children: [
          TextField(
              controller: _seedController,
              decoration: InputDecoration(
                  border: OutlineInputBorder(), labelText: "Seed"),
              inputFormatters: [
                WhitelistingTextInputFormatter(RegExp("[0-9a-fA-F]"))
              ],
              onChanged: (text) => Settings.setValue('seed', text)),
          Divider(color: Colors.transparent),
          TextField(
              controller: _initialFrameController,
              decoration: InputDecoration(
                border: OutlineInputBorder(),
                labelText: "Initial Frame",
              ),
              keyboardType: TextInputType.number,
              onChanged: (text) => Settings.setValue('initialFrame', text)),
          Divider(color: Colors.transparent),
          TextField(
              controller: _maxResultsController,
              decoration: InputDecoration(
                  border: OutlineInputBorder(), labelText: "Max Results"),
              keyboardType: TextInputType.number,
              onChanged: (text) => Settings.setValue('maxResults', text)),
          DropdownButtonFormField(
            decoration: InputDecoration(labelText: 'Location'),
            isExpanded: true,
            value: _locationDropDownValue,
            items: _locations,
            onChanged: (int value){
              setState(() {
                _locationDropDownValue = value;
                _dens = _createDenItems();
                _denDropDownValue = _dens[0].value;
                _raids = _createRaidItems();
                _raidsDropDownValue = _raids[0].value;
              });
            },
          ),
          DropdownButtonFormField(
              decoration: InputDecoration(labelText: 'Den'),
              isExpanded: true,
              value: _denDropDownValue,
              items: _dens,
              onChanged: (int value) {
                setState(() {
                  _denDropDownValue = value;
                  _raids = _createRaidItems();
                  _raidsDropDownValue = _raids[0].value;
                });

                Settings.setValue('den', _denDropDownValue);
                Settings.setValue('raid', _raidsDropDownValue);
              }),
          DropdownButtonFormField(
              decoration: InputDecoration(labelText: 'Raid'),
              isExpanded: true,
              value: _rarityDropDownValue,
              items: _rarities,
              onChanged: (int value) {
                setState(() {
                  _rarityDropDownValue = value;
                  _raids = _createRaidItems();
                  _raidsDropDownValue = _raids[0].value;
                });

                Settings.setValue('raid', _raidsDropDownValue);
              }),
          DropdownButtonFormField(
            decoration: InputDecoration(labelText: 'Game'),
            isExpanded: true,
            value: _gamesDropDownValue,
            items: _games,
            onChanged: (Game value) {
              setState(() {
                _gamesDropDownValue = value;
                _raids = _createRaidItems();
                _raidsDropDownValue = _raids[0].value;
              });

              Settings.setValue(
                  'game', Game.values.indexOf(_gamesDropDownValue));
              Settings.setValue('raid', _raidsDropDownValue);
            },
          ),
          DropdownButtonFormField(
              decoration: InputDecoration(labelText: 'Rarity'),
              isExpanded: true,
              value: _raidsDropDownValue,
              items: _raids,
              onChanged: (int value) {
                setState(() => _raidsDropDownValue = value);
                Settings.setValue('rarity', _raidsDropDownValue);
              }),
          RaisedButton(child: Text('Generate'), onPressed: () => _generate()),
          RaisedButton(
              child: Text('Filters'),
              onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => Filters(data: _data)))
                  .then((value) => _data = value)),
          SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: DataTable(
                  columns: [
                    DataColumn(label: Text('Frame')),
                    DataColumn(label: Text('IVs')),
                    DataColumn(label: Text('Shiny')),
                    DataColumn(label: Text('Nature')),
                    DataColumn(label: Text('Ability')),
                    DataColumn(label: Text('Gender'))
                  ],
                  rows: List.generate(
                      _frames.length, (index) => _getDataRow(_frames[index]))))
        ]));
  }

  void _generate() {
    var seed;
    if (BigInt.tryParse(_seedController.text, radix: 16) == null) {
      seed = 0;
    } else {
      seed = BigInt.parse(_seedController.text, radix: 16).toSigned(64).toInt();
    }

    var initialFrame = int.tryParse(_initialFrameController.text);
    if (initialFrame == null) {
      initialFrame = 1;
    }

    var maxResults = int.tryParse(_maxResultsController.text);
    if (maxResults == null) {
      maxResults = 100;
    }

    var den = DenLoader.getDen(_denDropDownValue, _rarityDropDownValue);
    var raid = den.getRaid(_raidsDropDownValue, _gamesDropDownValue);
    _info = PersonalLoader.getInfo(raid.species, raid.altform);

    var generator = RaidGenerator(initialFrame, maxResults, raid);
    var filter = FrameFilter(_data.ivs, _data.natures, _data.gender,
        _data.ability, _data.shiny, _data.skip);

    generator
        .generate(filter, seed)
        .then((frames) => setState(() => _frames = frames));
  }

  List<DropdownMenuItem<int>> _createDenItems() {
    var items = List<DropdownMenuItem<int>>();

    int start = _locationDropDownValue == 0 ? 0 : 100;
    int end = _locationDropDownValue == 0 ? 100 : 190;
    int offset = _locationDropDownValue == 0 ? 0 : 100;

    for (int i = start; i < end; i++) {
      var location = DenLoader.getLocation(i);
      var name = '${i + 1 - offset}: ${Translator.getLocation(location)}';

      items.add(DropdownMenuItem(value: i, child: Text(name)));
    }

    return items;
  }

  List<DropdownMenuItem<int>> _createRaidItems() {
    var items = List<DropdownMenuItem<int>>();
    var den = DenLoader.getDen(_denDropDownValue, _rarityDropDownValue);
    var raids = den.getRaids(_gamesDropDownValue);

    for (int i = 0; i < raids.length; i++) {
      var raid = raids[i];

      var string =
          raid.getStarRange() + ' ' + Translator.getSpecie(raid.species);
      string += ' (${raid.ivCount} IVs';
      string += raid.ability == 4 ? ' | HA' : '';
      string += raid.shinyType != 0 ? ' | Forced shiny' : '';
      string += raid.gigantamax ? ' | Giga' : '';
      string += ')';

      items.add(DropdownMenuItem(value: i, child: Text(string)));
    }

    return items;
  }

  DataRow _getDataRow(Frame result) {
    var frame = result.frame.toString();
    var ivs =
        '${result.getIV(0)}.${result.getIV(1)}.${result.getIV(2)}.${result.getIV(3)}.${result.getIV(4)}.${result.getIV(5)}';
    var shiny =
        result.shiny == 0 ? 'No' : result.shiny == 1 ? 'Star' : 'Square';
    var nature = Translator.getNature(result.nature);
    var ability =
        (result.ability == 2 ? 'HA: ' : (result.ability + 1).toString() + ': ') +
            Translator.getAbility(_info.getAbility(result.ability));
    var gender = result.gender == 0 ? '♂' : result.gender == 1 ? '♀' : '-';

    return DataRow(cells: [
      DataCell(Text(frame)),
      DataCell(Text(ivs)),
      DataCell(Text(shiny)),
      DataCell(Text(nature)),
      DataCell(Text(ability)),
      DataCell(Text(gender))
    ]);
  }
}
