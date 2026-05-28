<!-- - First thing i have to make the app so that it will allow to enter only the pin or the fingureprint also.
    -- And give option so that rather than only giving the option for the strong password we can choose either of them ok. -->
- Second thing i have to add the starting loading screens and also the App Logo also.
- Add option so that if forgoten the master password i am able to reset it using the email address.


 <!-- Random "screen" like bcrypt to slow cracking — yes, this is exactly what a good KDF does. What you're describing:
  - bcrypt — slow hash, has "cost factor" (work factor), gets slower as you raise it
  - Argon2 — even better, modern standard, uses memory + time to slow GPUs
  - scrypt — similar, memory-hard -->



-- Make the eye button in the import page make it bigger ok.  And rethink that page and recreate it. 
-- What happenes when i click the import button if the csv file passowrds i have already imported and i will import once again ??


<!-- 20-05-2026 -->
-- I can add the categories later on.  --  Future Work.
-- Make the auto generate password capable to generate the 256 character password.  
    -- I have to add Below a navbar where i have settings button, this password generator button and homepage for the main page.
<!-- -- Before there was one option to copy the old password but now it is missing.  -- Completed -->
<!-- -- i am alwasys showing the message that valut is locked after it was inactive even though it is never locked at all.  -- Completed.-->



<!-- 28-05-2026 -->
-- Pin screen is taking too much time to verify and open the screen -- After reducing complexitly for opening password still it takes too much time it must open the app in under 0.5 secs. 
-- Have to test if the locking the screen is working or not.
    -- Is it locking even if user is using the site??
    -- Than is it locking the app if ideal for auto-lock is set??
    -- And what if i goes to other site for too long what happens, is it asking me password only than or even if i come back immedialty. 
-- When i click the edit button to change the password or any other thing in the save password there we must have to show the passowrd and no need for the viewing blocked by deafult there.
-- After i have serached any password and i am trying to open it, it is not opening. 
    -- But if i try to open password without it, i am able to see the password all the details properly.
-- In settings page i am seeing import backup from .enc file but when i am opening that it is showing all other type of file other than the .enc so we have to show the .enc data files only.

-- Notes are visible in the center. so have to put it in the left. 