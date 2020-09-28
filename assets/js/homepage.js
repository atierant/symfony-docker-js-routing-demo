document.addEventListener('DOMContentLoaded', function () {
    var resultEl = document.getElementById('result');
    resultEl.innerHTML(Routing.generate('homepage'));
});
