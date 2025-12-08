const moment = require('moment');

function getUserInput(prompt) {
    return new Promise((resolve) => {
        process.stdout.write(prompt);
        process.stdin.on('data', (data) => resolve(data.toString().trim()));
    });
}

async function main() {
    const inputDate = await getUserInput('Please enter a date (YYYY-MM-DD): ');
    const userDate = moment(inputDate, 'YYYY-MM-DD');
    if (userDate.isValid()) {
        const formattedDate = userDate.format('MMMM Do YYYY, h:mm:ss a');
        console.log('Formatted Date:', formattedDate);
    } else {
        console.log('Invalid date format. Please enter a date in YYYY-MM-DD format.');
    }
    process.stdin.end();
}

main();
