# NappyCat on Linux

Firebase has no Linux SDK for Flutter desktop, so there is no native build.
This wrapper opens the hosted app in a chromeless app-mode window instead —
same letters, same account model, same cat.

Install:

    sudo cp nappycat /usr/local/bin/
    cp nappycat.desktop ~/.local/share/applications/

Then launch "NappyCat" from your app menu. For the full app rather than the
mini widget, edit the URL in /usr/local/bin/nappycat to drop `?mini=1`.
