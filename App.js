// Importa i moduli necessari
import React, { useState, useEffect, createContext, useContext } from 'react';
import './App.css';
import FirstPage from './client/PaginaIniziale';
import axios from 'axios';
import { BrowserRouter as Router, Route, Routes } from 'react-router-dom';
import { ThemeProvider, CssBaseline, IconButton } from '@mui/material';
import { createTheme } from '@mui/material/styles';
import { Brightness4 as DarkIcon, Brightness7 as LightIcon } from '@mui/icons-material';
import Home from './client/Homepage';
import Carrello from './client/AcquistaCanale';
import Carrello1 from './client/AcquistaCaratteri';
import UtenteInfoPage from './client/ProfiloUtente';
import NewFollow from './client/IscrizioneCanale';
import CreaCanalePage from './client/CreazioneCanale';
import NotificationPage from './client/Richieste';

// Crea un contesto per il tema
const ThemeContext = createContext();

function App() {
  const [darkMode, setDarkMode] = useState(false);

  const handleDarkModeChange = () => {
    setDarkMode(!darkMode);
  };

  useEffect(() => {
    axios.get('http://localhost:3001/api/get').then((response) => {
      console.log(response);
    });
  }, []);

  // Crea un tema basato sullo stato del dark mode
  const theme = createTheme({
    palette: {
      mode: darkMode ? 'dark' : 'light',
    },
  });

  return (
    <ThemeContext.Provider value={{ darkMode, handleDarkModeChange }}>
      <ThemeProvider theme={theme}>
        <CssBaseline />
        <div className="App">
            <Routes>
              <Route path='/' element={<FirstPage />} />
              <Route path='/Home' element={<Home />} />
              <Route path='/AcquistaCaratteri' element={<Carrello1 />} />
              <Route path='/AcquistaCanale' element={<Carrello />} />
              <Route path='/UtenteInfoPage' element={<UtenteInfoPage />} /> 
              <Route path='/NewFollow' element={<NewFollow />} />    
              <Route path='/CreaCanalePage' element={<CreaCanalePage />} />  
              <Route path='/NotificationPage' element={<NotificationPage />} />        
            </Routes>
        </div>
      </ThemeProvider>
    </ThemeContext.Provider>
  );
}

// Creare un hook personalizzato per il tema
export const useThemeContext = () => {
  return useContext(ThemeContext);
};

export default App;
