import 'package:expense_tracker/utils/route.dart';
import 'package:flutter/material.dart';

class SignupScreen extends StatelessWidget {
  //input controllers
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green,
      body: SafeArea(
        child: Column(
          children: [
            
            Container(
              width: double.infinity,
              height: 250,
              decoration: BoxDecoration(
                color: Colors.green
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24,vertical: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text("Hiiii!",style: TextStyle(fontSize: 36,fontWeight: FontWeight.bold,color: Colors.white),),
                    const Text("Welcome to Expensify",style: TextStyle(color: Colors.white,fontSize: 12),)
                  ],
                ),
              ),
            ),

            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24,vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.only(topLeft: Radius.circular(26),topRight: Radius.circular(26))
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    
                    // const SizedBox(height: 30,),
                    //app logo
                    // Center(
                    //   child: Container(
                    //     height: 60,
                    //     width: 60,
                    //     decoration: BoxDecoration(
                    //       color: Colors.green,
                    //       border: Border.all(color: Colors.greenAccent,width: 2),
                    //       borderRadius: BorderRadius.circular(30),
                    //     ),
                    //     child: Center(
                    //       child: Text("\$",style: TextStyle(
                    //         fontSize: 28,
                    //         fontWeight: FontWeight.bold,
                    //         color: Colors.white,
                    //       ),),
                    //     ),
                    //   ),
                    // ),
                            
                    const SizedBox(height: 40,),
                    //sign in text
                    const Text(
                      "Sign Up",
                      style: TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.green
                      ),
                    ),
                    SizedBox(height: 30,),
                            
                    TextFormField(
                      controller: emailController,
                      decoration: InputDecoration(
                        labelText: "Email",
                        hintText: "ex: akii@gmail.com",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)
                      ),
                    ),
                    SizedBox(height: 16,),
                    TextFormField(
                      obscureText: true,
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: "Password",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)
                      ),
                    ),
                    SizedBox(height: 16,),
                    TextFormField(
                      obscureText: true,
                      controller: passwordController,
                      decoration: InputDecoration(
                        labelText: "Confirm Password",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                         contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14)
                      ),
                    ),
                    SizedBox(height: 24,),
                    //signup button
                    SizedBox(
                      width: double.infinity,
                      height: 48,
                      child: ElevatedButton(
                        onPressed: (){
                          
                        }, 
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          shape: RoundedRectangleBorder(borderRadius:BorderRadiusGeometry.circular(15) )
                        ),
                        child: const Text("Signup",style: TextStyle(fontSize: 16,fontWeight: FontWeight.bold,color: Colors.white),),
                        ),
                    ),
                    const SizedBox(height: 16,),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Already have an account?",style: TextStyle(color: Colors.grey),),
                        SizedBox(width: 5,),
                        InkWell(
                          splashColor: Colors.green,
                          onTap: () {
                            //send to signup screen
                            Navigator.pushNamed(context, AppRoutes.signin);
                          },
                          child: Text("Sign In",style: TextStyle(color: Colors.green),)),
                        
                      ],
                    )
                
                
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );

  }
}