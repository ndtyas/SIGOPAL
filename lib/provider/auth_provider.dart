import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


final _fireAuth = FirebaseAuth.instance;
class AuthProvider extends ChangeNotifier{
  final form = GlobalKey<FormState>();

  var islogin = true;
  var enteredEmail = '';
  var enteredPassword = '';
  
  void submit() async{
    final isvalid = form.currentState!.validate();

    if(!isvalid){
      return;
    }

    form.currentState!.save();

    try{
      if(islogin){
        await _fireAuth.signInWithEmailAndPassword(email: enteredEmail, password: enteredPassword);
      }else{
        await _fireAuth.createUserWithEmailAndPassword(email: enteredEmail, password: enteredPassword);
      }
    }catch(e){
      if(e is FirebaseAuthException){
        if(e.code == 'email-already-in-use' ){
          print("email already in use");
        }
      }
    }


    notifyListeners();
  }

}