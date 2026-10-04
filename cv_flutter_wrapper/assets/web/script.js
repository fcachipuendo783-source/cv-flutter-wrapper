function cambiarTema() {
  document.body.classList.toggle("dark");
}

document.addEventListener("DOMContentLoaded", function () {
  const titulo = document.querySelector("header h1");

  titulo.addEventListener("click", function () {
    alert("Bienvenido a mi Hoja de Vida");
  });
});