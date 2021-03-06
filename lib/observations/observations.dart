import 'dart:async';

import 'package:abherbs_flutter/entity/observation.dart';
import 'package:abherbs_flutter/generated/l10n.dart';
import 'package:abherbs_flutter/observations/observation_upload.dart';
import 'package:abherbs_flutter/observations/observation_view.dart';
import 'package:abherbs_flutter/purchase/purchases.dart';
import 'package:abherbs_flutter/purchase/subscription.dart';
import 'package:abherbs_flutter/utils/dialogs.dart';
import 'package:abherbs_flutter/utils/utils.dart';
import 'package:abherbs_flutter/widgets/firebase_animated_list.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';

class Observations extends StatefulWidget {
  final FirebaseUser currentUser;
  final Locale myLocale;
  final void Function(String) onChangeLanguage;
  final bool isPublicOnly;
  Observations(this.currentUser, this.myLocale, this.onChangeLanguage, this.isPublicOnly);

  @override
  _ObservationsState createState() => _ObservationsState();
}

const Key _publicKey = Key('public');
const Key _privateKey = Key('private');

class _ObservationsState extends State<Observations> {
  Key _key;
  bool _isPublic;
  Query _privateQuery;
  Query _publicQuery;
  Query _query;
  Future<int> _countUploadF;

  void _setIsPublic(bool isPublic) {
    if (Purchases.isSubscribed()) {
      setState(() {
        _isPublic = isPublic;
        _key = _isPublic ? _publicKey : _privateKey;
        _query = _isPublic ? _publicQuery : _privateQuery;
      });
    } else {
      subscriptionDialog(context, S.of(context).subscription, S.of(context).subscription_info).then((value) {
        if (value != null && value) {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => Subscription()),
          );
        }
      });
    }
  }

  void _setCountUploadF() {
    if (Purchases.isSubscribed()) {
      privateObservationsReference.child(widget.currentUser.uid).child(firebaseObservationsByDate).child(firebaseAttributeList).keepSynced(true);
      _countUploadF = privateObservationsReference
          .child(widget.currentUser.uid)
          .child(firebaseObservationsByDate)
          .child(firebaseAttributeList)
          .orderByChild(firebaseAttributeStatus)
          .equalTo(firebaseValuePrivate)
          .once()
          .then((DataSnapshot snapshot) {
        return snapshot.value?.length ?? 0;
      });
    } else {
      _countUploadF = Future<int>(() {
        return 0;
      });
    }
  }

  Future<void> _uploadObservationDialog(int observationsToUpload) async {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return ObservationUpload(widget.currentUser, observationsToUpload);
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _key = _privateKey;
    initializeDateFormatting();
    _publicQuery = publicObservationsReference.child(firebaseObservationsByDate).child(firebaseAttributeList).orderByChild(firebaseAttributeOrder);
    if (widget.isPublicOnly) {
      _isPublic = true;
      _query = _publicQuery;
    } else {
      _isPublic = false;
      _privateQuery = privateObservationsReference
          .child(widget.currentUser.uid)
          .child(firebaseObservationsByDate)
          .child(firebaseAttributeList)
          .orderByChild(firebaseAttributeOrder);
      _query = _privateQuery;
    }

    _setCountUploadF();
  }

  @override
  Widget build(BuildContext context) {
    var myLocale = Localizations.localeOf(context);

    List<Widget> appBarItems = [];
    appBarItems.add(Text(S.of(context).observations));
    if (widget.isPublicOnly) {
      appBarItems.add(Icon(Icons.people));
    } else {
      appBarItems.add(Row(
        children: [
          Icon(Icons.person),
          Switch(
            value: _isPublic,
            activeColor: Colors.white,
            inactiveThumbColor: Colors.white,
            onChanged: (bool value) {
              _setIsPublic(value);
            },
          ),
          Icon(Icons.people),
        ],
      ));
    }

    return Scaffold(
      key: _key,
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: appBarItems,
        ),
      ),
      body: MyFirebaseAnimatedList(
          key: _key,
          defaultChild: Center(child: CircularProgressIndicator()),
          emptyChild: Container(
            padding: EdgeInsets.all(5.0),
            alignment: Alignment.center,
            child: Text(S.of(context).observation_empty, style: TextStyle(fontSize: 20.0)),
          ),
          query: _query,
          itemBuilder: (_, DataSnapshot snapshot, Animation<double> animation, int index) {
            Observation observation = Observation.fromJson(snapshot.key, snapshot.value);
            return ObservationView(widget.currentUser, myLocale, widget.onChangeLanguage, observation);
          }),
      floatingActionButton: FutureBuilder<int>(
          future: _countUploadF,
          builder: (BuildContext context, AsyncSnapshot<int> snapshot) {
            switch (snapshot.connectionState) {
              case ConnectionState.done:
                if (snapshot.data > 0) {
                  return Container(
                    height: 70.0,
                    width: 70.0,
                    child: FittedBox(
                      fit: BoxFit.fill,
                      child: FloatingActionButton(
                    onPressed: () {
                      _uploadObservationDialog(snapshot.data).then((value) {
                        setState(() {
                          _setCountUploadF();
                        });
                      });
                    },
                    child: Icon(Icons.cloud_upload),
                  ),),);
                }
                return Container(width: 0.0, height: 0.0,);
              default: return Container(width: 0.0, height: 0.0,);
            }
          }),
    );
  }
}
