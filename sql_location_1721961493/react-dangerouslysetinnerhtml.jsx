import sanitize from "xss"
function TestComponent2(foo) {
    // ok:react-dangerouslysetinnerhtml
    let params = {smth: 'test123', dangerouslySetInnerHTML: {__html: sanitize(foo)},a:b};
    return React.createElement('div', params);
}
